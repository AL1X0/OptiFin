using System.Text.RegularExpressions;

namespace OptiFin.Core.Auth;

/// <summary>Règles pures autour des adresses et versions de serveur (sans réseau, testées).</summary>
public static partial class ServerAddress
{
    public const int DefaultHttpPort = 8096;
    public static readonly Version MinimumVersion = new(10, 9, 0);

    [GeneratedRegex("^[a-zA-Z][a-zA-Z0-9+.-]*://")]
    private static partial Regex SchemePattern();

    [GeneratedRegex(@"^(\d+)\.(\d+)(?:\.(\d+))?")]
    private static partial Regex VersionPattern();

    /// <summary>
    /// Saisie utilisateur → URL candidates, dans l'ordre d'essai : <c>https://x</c> et
    /// <c>http://x</c> tels quels ; sans schéma, https puis http, puis http:8096 si aucun port.
    /// </summary>
    public static IReadOnlyList<Uri> Candidates(string input)
    {
        var raw = input.Trim();
        if (raw.Length == 0) return [];
        var hasScheme = SchemePattern().IsMatch(raw);
        raw = raw.TrimEnd('/');

        if (hasScheme)
        {
            if (!Uri.TryCreate(raw, UriKind.Absolute, out var uri) || uri.Host.Length == 0 ||
                (uri.Scheme != "http" && uri.Scheme != "https"))
            {
                return [];
            }
            return [Normalize(uri)];
        }

        if (!Uri.TryCreate("https://" + raw, UriKind.Absolute, out var https) || https.Host.Length == 0) return [];
        var http = new Uri("http://" + raw);
        var explicitPort = HasExplicitPort(raw);
        var result = new List<Uri> { Normalize(https), Normalize(http) };
        if (!explicitPort) result.Add(Normalize(new UriBuilder(http) { Port = DefaultHttpPort }.Uri));
        return result;
    }

    private static bool HasExplicitPort(string hostAndPath)
    {
        var authority = hostAndPath.Split('/', 2)[0];
        if (authority.StartsWith('['))
        {
            var close = authority.IndexOf(']');
            return close >= 0 && authority.Length > close + 1 && authority[close + 1] == ':';
        }
        return authority.Contains(':');
    }

    /// <summary>Sans requête ni fragment ni « / » final ; garde un sous-chemin (https://h/jellyfin).</summary>
    public static Uri Normalize(Uri uri)
    {
        var builder = new UriBuilder(uri.Scheme.ToLowerInvariant(), uri.Host.ToLowerInvariant())
        {
            Path = uri.AbsolutePath.TrimEnd('/'),
            Port = uri.IsDefaultPort ? -1 : uri.Port,
        };
        return builder.Uri;
    }

    /// <summary>« 10.10.3 » ou « 10.11.0-rc1 » → 10.10.3. Null si illisible.</summary>
    public static Version? ParseVersion(string? version)
    {
        if (version is null) return null;
        var m = VersionPattern().Match(version.Trim());
        if (!m.Success) return null;
        return new Version(int.Parse(m.Groups[1].Value), int.Parse(m.Groups[2].Value),
            m.Groups[3].Success ? int.Parse(m.Groups[3].Value) : 0);
    }

    public static bool IsSupportedVersion(string? version) =>
        ParseVersion(version) is { } v && v >= MinimumVersion;
}
