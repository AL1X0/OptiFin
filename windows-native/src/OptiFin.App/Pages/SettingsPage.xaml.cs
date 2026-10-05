using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using OptiFin.App.Controls;
using OptiFin.App.Services;
using OptiFin.Core.Logging;
using OptiFin.Core.Settings;

namespace OptiFin.App.Pages;

/// <summary>Réglages : compte, lecture et sous-titres, avancé (debug, journaux), à propos et mises à jour.</summary>
public sealed partial class SettingsPage : Page
{
    private AppSettings S => AppServices.Settings;

    public SettingsPage()
    {
        InitializeComponent();
        Nav.TrackScroll(Scroll);
        BuildAccount();
        BuildPlayback();
        BuildAdvanced();
        BuildAbout();
    }

    private void Save() => AppServices.SaveSettings();

    private static Grid Row(string label, string? detail, FrameworkElement control)
    {
        var grid = new Grid { Padding = new Thickness(16, 12, 16, 12), CornerRadius = new CornerRadius(12), Background = Ui.Res("OFSurfaceBrush"), ColumnSpacing = 24 };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var texts = new StackPanel { VerticalAlignment = VerticalAlignment.Center, Spacing = 2 };
        texts.Children.Add(new TextBlock { Text = label, FontSize = 15 });
        if (detail != null) texts.Children.Add(new TextBlock { Text = detail, Style = Ui.StyleOf("OFCaption"), TextWrapping = TextWrapping.Wrap, TextTrimming = TextTrimming.None });
        grid.Children.Add(texts);
        control.VerticalAlignment = VerticalAlignment.Center;
        Grid.SetColumn(control, 1);
        grid.Children.Add(control);
        return grid;
    }

    private static ComboBox Choice(IEnumerable<string> labels, int selected, Action<int> changed)
    {
        var box = new ComboBox { MinWidth = 220 };
        foreach (var l in labels) box.Items.Add(l);
        box.SelectedIndex = Math.Max(0, selected);
        box.SelectionChanged += (_, _) => changed(box.SelectedIndex);
        return box;
    }

    private static ToggleSwitch Toggle(bool value, Action<bool> changed)
    {
        var t = new ToggleSwitch { IsOn = value, OnContent = "", OffContent = "", MinWidth = 0 };
        t.Toggled += (_, _) => changed(t.IsOn);
        return t;
    }

    // ------------------------------------------------------------ Compte

    private void BuildAccount()
    {
        Panel.Children.Add(Ui.Section("Compte"));
        if (AppServices.Session is { } s)
        {
            var avatar = Ui.Avatar(s.Account.UserName,
                s.Account.AvatarTag is null ? null : AppServices.Images?.UserAvatar(s.Account.UserId, 48, 2, s.Account.AvatarTag), 48);
            var buttons = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
            var change = Ui.Secondary("Changer de compte");
            change.Click += (_, _) => Nav.PushRoot(typeof(ConnectPage));
            var signOut = Ui.Secondary("Se déconnecter");
            signOut.Click += async (_, _) => await AppServices.SignOutAsync();
            buttons.Children.Add(change);
            buttons.Children.Add(signOut);
            var row = Row(s.Account.UserName, $"{s.Server.Name} · {s.Server.BaseUrl}", buttons);
            var left = (StackPanel)row.Children[0];
            row.Children.Remove(left);
            var head = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 14 };
            head.Children.Add(avatar);
            head.Children.Add(left);
            row.Children.Insert(0, head);
            Panel.Children.Add(row);
        }
    }

    // ------------------------------------------------------------ Lecture

    private void BuildPlayback()
    {
        Panel.Children.Add(Ui.Section("Lecture"));
        var languages = AppSettings.Languages;
        var languageLabels = new[] { "Automatique" }.Concat(languages.Select(l => l.Name)).ToList();
        int IndexOf(string? code) => code is null ? 0 : languages.ToList().FindIndex(l => l.Code == code) + 1;

        Panel.Children.Add(Row("Langue audio", "Piste choisie si elle existe (sinon celle du serveur).",
            Choice(languageLabels, IndexOf(S.AudioLanguage), i => { S.AudioLanguage = i == 0 ? null : languages[i - 1].Code; Save(); })));
        Panel.Children.Add(Row("Sous-titres", null,
            Choice(Enum.GetValues<SubtitleMode>().Select(AppSettings.Label), (int)S.SubtitleMode, i => { S.SubtitleMode = (SubtitleMode)i; Save(); })));
        Panel.Children.Add(Row("Langue des sous-titres", null,
            Choice(languageLabels, IndexOf(S.SubtitleLanguage), i => { S.SubtitleLanguage = i == 0 ? null : languages[i - 1].Code; Save(); })));

        var size = new Slider { Minimum = 60, Maximum = 200, StepFrequency = 10, Value = S.SubtitleScale * 100, Width = 220 };
        size.ValueChanged += (_, e) => { S.SubtitleScale = e.NewValue / 100; Save(); };
        Panel.Children.Add(Row("Taille des sous-titres", null, size));
        Panel.Children.Add(Row("Fond des sous-titres", null,
            Choice(["Contour", "Ombre", "Bandeau"], (int)S.SubtitleBackground, i => { S.SubtitleBackground = (SubtitleBackground)i; Save(); })));

        var bitrates = AppSettings.Bitrates;
        Panel.Children.Add(Row("Débit maximal", "Au-delà, le serveur adapte la vidéo (utile hors de chez soi).",
            Choice(bitrates.Select(b => b.Label), bitrates.ToList().FindIndex(b => b.Bitrate == S.MaxBitrate), i => { S.MaxBitrate = bitrates[i].Bitrate; Save(); })));
        Panel.Children.Add(Row("Passer l’intro automatiquement", "Intro, récapitulatif et publicité, quand le serveur les connaît.",
            Toggle(S.AutoSkipSegments, v => { S.AutoSkipSegments = v; Save(); })));
        Panel.Children.Add(Row("Épisode suivant automatique", "Enchaîne l’épisode suivant à la fin du générique.",
            Toggle(S.AutoPlayNext, v => { S.AutoPlayNext = v; Save(); })));
    }

    // ------------------------------------------------------------ Avancé

    private void BuildAdvanced()
    {
        Panel.Children.Add(Ui.Section("Avancé"));
        Panel.Children.Add(Row("Mode debug", "Infos de lecture affichées dès le lancement d’une vidéo (aussi via le bouton ⓘ ou la touche I du lecteur), journaux détaillés.",
            Toggle(S.DebugMode, v => { S.DebugMode = v; AppLog.Verbose = v; Save(); })));
        var logs = Ui.Secondary("Ouvrir");
        logs.Click += (_, _) => Nav.Go(typeof(LogsPage));
        Panel.Children.Add(Row("Journaux", "Pour diagnostiquer un problème (les secrets sont masqués).", logs));

        var clear = Ui.Secondary("Vider");
        var cacheStatus = new TextBlock { Style = Ui.StyleOf("OFCaption"), VerticalAlignment = VerticalAlignment.Center };
        var cacheRow = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 12 };
        cacheRow.Children.Add(cacheStatus);
        cacheRow.Children.Add(clear);
        clear.Click += (_, _) =>
        {
            var freed = ClearCache();
            cacheStatus.Text = freed > 0 ? $"{freed / 1024.0 / 1024.0:0.#} Mo libérés" : "Cache vidé";
        };
        Panel.Children.Add(Row("Vider le cache", "Accueil enregistré pour l’affichage instantané et couleurs des films (recalculés au besoin).", cacheRow));

        Panel.Children.Add(Row("Capacités de l’appareil", DeviceSummary(), new Border()));
    }

    /// <summary>Supprime le cache disque (accueil) et vide les couleurs mémorisées ; renvoie les octets libérés.</summary>
    private static long ClearCache()
    {
        long freed = 0;
        var dir = Path.Combine(AppLog.Directory, "cache");
        try
        {
            if (Directory.Exists(dir))
            {
                foreach (var file in Directory.EnumerateFiles(dir))
                {
                    freed += new FileInfo(file).Length;
                    File.Delete(file);
                }
            }
        }
        catch (IOException)
        {
        }
        catch (UnauthorizedAccessException)
        {
        }
        FilmAccent.Clear();
        AppLog.Info("app", $"Cache vidé ({freed} octets)");
        return freed;
    }

    private static string DeviceSummary()
    {
        var os = Environment.OSVersion.Version;
        var windows = os.Build >= 22000 ? "Windows 11" : "Windows 10";
        var memory = GC.GetGCMemoryInfo().TotalAvailableMemoryBytes / 1024.0 / 1024 / 1024;
        return $"{windows} (build {os.Build}) · {Environment.ProcessorCount} cœurs · {memory:0} Go de mémoire · " +
               "lecture mpv (gpu-next, Direct3D 11, décodage matériel, HDR transmis à l’écran quand Windows l’active)";
    }

    // ------------------------------------------------------------ À propos

    private void BuildAbout()
    {
        Panel.Children.Add(Ui.Section("À propos"));
        var check = Ui.Secondary("Rechercher");
        var status = new TextBlock { Style = Ui.StyleOf("OFCaption"), VerticalAlignment = VerticalAlignment.Center };
        var stack = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 12 };
        stack.Children.Add(status);
        stack.Children.Add(check);
        check.Click += async (_, _) =>
        {
            status.Text = "Recherche…";
            var update = await AppUpdater.CheckAsync();
            if (update is null)
            {
                status.Text = "OptiFin est à jour.";
                return;
            }
            status.Text = $"Version {update.Version} disponible.";
            await UpdateDialog.ShowAsync(XamlRoot, update);
        };
        Panel.Children.Add(AppUpdater.ByStore
            ? Row($"OptiFin {AppServices.Version}", "Lecteur Jellyfin pour Windows · mises à jour par le Microsoft Store.", new TextBlock())
            : Row($"OptiFin {AppServices.Version}", "Lecteur Jellyfin pour Windows · mises à jour automatiques.", stack));
        var licences = Ui.Secondary("Afficher");
        licences.Click += async (_, _) => await ShowLicencesAsync();
        Panel.Children.Add(Row("Licences", "Composants libres utilisés par OptiFin.", licences));
    }

    private async Task ShowLicencesAsync()
    {
        var list = new StackPanel { Spacing = 10 };
        foreach (var (name, licence) in new[]
        {
            ("mpv / libmpv (mpv.io, build shinchiro)", "GPL v2 ou ultérieure / LGPL v2.1 ou ultérieure selon la compilation ; inclut FFmpeg (LGPL / GPL)"),
            ("Windows App SDK et WinUI 3 (Microsoft)", "Licence MIT"),
            (".NET (Microsoft)", "Licence MIT"),
            ("Inno Setup (installateur)", "Licence Inno Setup"),
            ("Jellyfin (serveur, API)", "GPL v2 ; OptiFin est un client indépendant"),
        })
        {
            var item = new StackPanel { Spacing = 2 };
            item.Children.Add(new TextBlock { Text = name, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, TextWrapping = TextWrapping.Wrap });
            item.Children.Add(Ui.Text(licence, "OFCaption"));
            list.Children.Add(item);
        }
        var dialog = new ContentDialog
        {
            XamlRoot = XamlRoot,
            Title = "Licences",
            CloseButtonText = "Fermer",
            RequestedTheme = ElementTheme.Dark,
            Content = new ScrollViewer { Content = list, MaxHeight = 420, Width = 480 },
        };
        await dialog.ShowAsync();
    }
}
