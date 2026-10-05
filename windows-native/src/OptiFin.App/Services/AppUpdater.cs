using System.Diagnostics;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using OptiFin.Core.Logging;

namespace OptiFin.App.Services;

public sealed record AppUpdate(string Version, Uri Url, long Size, string? Sha256);

/// <summary>
/// Mise à jour automatique : la CI publie chaque version dans les Releases GitHub
/// (« OptiFin 1.0.N », installateur <c>OptiFin-windows-setup.exe</c>). L'appli compare avec sa
/// version, télécharge l'installateur, vérifie son empreinte SHA-256 annoncée par GitHub, puis lance
/// l'installation silencieuse, qui ferme et relance OptiFin.
/// </summary>
public static partial class AppUpdater
{
    public const string AssetName = "OptiFin-windows-setup.exe";
    /// <summary>Releases récentes : celles de l'appli PC (« OptiFin Windows 1.1.N ») et celles du mobile.</summary>
    private const string Releases = "https://api.github.com/repos/AL1X0/OptiFin/releases?per_page=30";

    private static readonly HttpClient Http = CreateHttp();

    private static HttpClient CreateHttp()
    {
        var http = new HttpClient { Timeout = TimeSpan.FromMinutes(10) };
        http.DefaultRequestHeaders.UserAgent.ParseAdd("OptiFin");
        http.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");
        return http;
    }

    [GeneratedRegex(@"(\d+\.\d+\.\d+)")]
    private static partial Regex VersionPattern();

    public static async Task<AppUpdate?> CheckAsync()
    {
        try
        {
            // La plus récente des versions publiées avec l'installateur PC (l'appli PC a ses propres
            // releases, « latest » peut être une version mobile).
            using var doc = JsonDocument.Parse(await Http.GetStringAsync(Releases));
            AppUpdate? best = null;
            foreach (var release in doc.RootElement.EnumerateArray())
            {
                if (release.TryGetProperty("draft", out var draft) && draft.GetBoolean()) continue;
                if (release.TryGetProperty("prerelease", out var pre) && pre.GetBoolean()) continue;
                // Seules les releases PC (tag windows-N) donnent la version de l'appli PC : les releases
                // mobiles et TV joignent aussi l'installateur, mais leur numéro est celui de leur appli.
                var tag = release.TryGetProperty("tag_name", out var t) ? t.GetString() ?? "" : "";
                if (!tag.StartsWith("windows-", StringComparison.Ordinal)) continue;
                var name = release.TryGetProperty("name", out var n) ? n.GetString() ?? "" : "";
                var match = VersionPattern().Match(name);
                if (!match.Success || Compare(match.Value, best?.Version ?? AppServices.Version) <= 0) continue;
                foreach (var asset in release.GetProperty("assets").EnumerateArray())
                {
                    if (asset.GetProperty("name").GetString() != AssetName) continue;
                    var digest = asset.TryGetProperty("digest", out var d) ? d.GetString() : null;
                    best = new AppUpdate(match.Value, new Uri(asset.GetProperty("browser_download_url").GetString()!),
                        asset.GetProperty("size").GetInt64(),
                        digest is not null && digest.StartsWith("sha256:", StringComparison.Ordinal) ? digest[7..] : null);
                }
            }
            if (best != null) AppLog.Info("update", $"Nouvelle version disponible : {best.Version} (installée : {AppServices.Version})");
            return best;
        }
        catch (Exception e)
        {
            AppLog.Debug("update", $"Vérification des mises à jour impossible : {e.Message}");
            return null;
        }
    }

    /// <summary>Comparaison numérique « 1.0.9 » &lt; « 1.0.10 ».</summary>
    public static int Compare(string a, string b)
    {
        static int[] Parts(string v) => [.. v.Split('.', '+').Take(3).Select(p => int.TryParse(p, out var x) ? x : 0)];
        var (pa, pb) = (Parts(a), Parts(b));
        for (var i = 0; i < 3; i++)
        {
            var x = i < pa.Length ? pa[i] : 0;
            var y = i < pb.Length ? pb[i] : 0;
            if (x != y) return x.CompareTo(y);
        }
        return 0;
    }

    public static async Task InstallAsync(AppUpdate update, IProgress<double> progress)
    {
        var path = Path.Combine(Path.GetTempPath(), $"OptiFin-{update.Version}-setup.exe");
        using (var response = await Http.GetAsync(update.Url, HttpCompletionOption.ResponseHeadersRead))
        {
            response.EnsureSuccessStatusCode();
            var total = response.Content.Headers.ContentLength ?? update.Size;
            await using var input = await response.Content.ReadAsStreamAsync();
            await using var output = File.Create(path);
            var buffer = new byte[1 << 16];
            long done = 0;
            int read;
            while ((read = await input.ReadAsync(buffer)) > 0)
            {
                await output.WriteAsync(buffer.AsMemory(0, read));
                done += read;
                if (total > 0) progress.Report((double)done / total);
            }
        }
        if (update.Sha256 is { } expected)
        {
            await using var file = File.OpenRead(path);
            var actual = Convert.ToHexString(await SHA256.HashDataAsync(file));
            if (!actual.Equals(expected, StringComparison.OrdinalIgnoreCase))
            {
                File.Delete(path);
                throw new InvalidOperationException("Installateur corrompu (empreinte inattendue) : téléchargement annulé.");
            }
        }
        AppLog.Info("update", $"Installation de la version {update.Version}");
        Process.Start(new ProcessStartInfo(path, "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS") { UseShellExecute = true });
        Environment.Exit(0);
    }
}

/// <summary>Fenêtre de mise à jour : version, taille, progression du téléchargement.</summary>
public static class UpdateDialog
{
    public static async Task ShowAsync(XamlRoot root, AppUpdate update)
    {
        var text = new TextBlock
        {
            Text = $"Une nouvelle version est disponible ({update.Size / 1024 / 1024} Mo). OptiFin se fermera, s’installera puis se relancera tout seul.",
            TextWrapping = TextWrapping.Wrap,
        };
        var bar = new ProgressBar { Visibility = Visibility.Collapsed, Margin = new Thickness(0, 12, 0, 0) };
        var panel = new StackPanel { Width = 420 };
        panel.Children.Add(text);
        panel.Children.Add(bar);
        var dialog = new ContentDialog
        {
            Title = $"OptiFin {update.Version}",
            Content = panel,
            PrimaryButtonText = "Installer",
            CloseButtonText = "Plus tard",
            DefaultButton = ContentDialogButton.Primary,
            XamlRoot = root,
            RequestedTheme = ElementTheme.Dark,
        };
        dialog.PrimaryButtonClick += async (_, args) =>
        {
            var deferral = args.GetDeferral();
            args.Cancel = true;
            dialog.IsPrimaryButtonEnabled = false;
            bar.Visibility = Visibility.Visible;
            try
            {
                await AppUpdater.InstallAsync(update, new Progress<double>(p =>
                {
                    bar.Value = p * 100;
                    text.Text = $"Téléchargement… {(int)(p * 100)} %";
                }));
            }
            catch (Exception e)
            {
                text.Text = e is InvalidOperationException ? e.Message : "Téléchargement impossible. Réessayez plus tard.";
                dialog.IsPrimaryButtonEnabled = true;
            }
            finally
            {
                deferral.Complete();
            }
        };
        await dialog.ShowAsync();
    }
}
