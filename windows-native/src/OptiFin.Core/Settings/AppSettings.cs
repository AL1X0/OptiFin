using System.Text.Json;
using System.Text.Json.Serialization;
using OptiFin.Core.Logging;
using OptiFin.Core.Playback;
using OptiFin.Core.Localization;

namespace OptiFin.Core.Settings;

public enum SubtitleMode { Server, Always, ForcedOnly, None }

public enum SubtitleBackground { None, Shadow, Box }

/// <summary>Réglages de l'appli (mêmes choix que sur iPhone et Android).</summary>
public sealed class AppSettings
{
    public bool DebugMode { get; set; }

    /// <summary>Débit maximal (bits/s) ; 0 = pas de limite côté client.</summary>
    public long MaxBitrate { get; set; }
    public string? AudioLanguage { get; set; }
    public string? SubtitleLanguage { get; set; }
    public SubtitleMode SubtitleMode { get; set; } = SubtitleMode.Server;
    public double SubtitleScale { get; set; } = 1;
    public SubtitleBackground SubtitleBackground { get; set; } = SubtitleBackground.None;
    public bool AutoSkipSegments { get; set; }
    public bool AutoPlayNext { get; set; } = true;
    public double Volume { get; set; } = 1;

    /// <summary>Son Dolby et DTS envoyé tel quel à l'ampli ou à la barre de son (HDMI, S/PDIF).</summary>
    public bool AudioPassthrough { get; set; }

    /// <summary>Résultat du dernier essai de décodage WebP sur ce PC (null : pas encore essayé).</summary>
    public bool? WebpDecodes { get; set; }

    public static string Label(SubtitleMode m) => m switch
    {
        SubtitleMode.Server => L.T("Réglage du serveur"),
        SubtitleMode.Always => L.T("Toujours"),
        SubtitleMode.ForcedOnly => L.T("Forcés uniquement"),
        _ => L.T("Jamais"),
    };

    /// <summary>Langues proposées (codes ISO 639-2 de Jellyfin).</summary>
    public static readonly IReadOnlyList<(string Code, string Name)> Languages =
    [
        ("fre", L.T("Français")), ("eng", L.T("Anglais")), ("spa", L.T("Espagnol")), ("ger", L.T("Allemand")), ("ita", L.T("Italien")),
        ("por", L.T("Portugais")), ("jpn", L.T("Japonais")), ("kor", L.T("Coréen")), ("chi", L.T("Chinois")), ("rus", L.T("Russe")),
        ("ara", L.T("Arabe")), ("dut", L.T("Néerlandais")),
    ];

    /// <summary>Débits proposés (bits/s). 0 = maximum (le serveur plafonne).</summary>
    public static readonly IReadOnlyList<(long Bitrate, string Label)> Bitrates =
    [
        (0, "Maximum"), (120_000_000, "120 Mb/s (4K)"), (60_000_000, "60 Mb/s"), (40_000_000, "40 Mb/s (1080p)"),
        (20_000_000, "20 Mb/s"), (10_000_000, "10 Mb/s (720p)"),
    ];

    public long EffectiveMaxBitrate => MaxBitrate > 0 ? MaxBitrate : PlaybackService.DefaultMaxBitrate;
}

[JsonSourceGenerationOptions(WriteIndented = true, UseStringEnumConverter = true)]
[JsonSerializable(typeof(AppSettings))]
internal sealed partial class SettingsJson : JsonSerializerContext;

/// <summary>Réglages enregistrés dans %LOCALAPPDATA%\OptiFin\settings.json.</summary>
public sealed class SettingsStore(string? directory = null)
{
    private readonly string _path = Path.Combine(directory ?? AppLog.Directory, "settings.json");

    public AppSettings Load()
    {
        try
        {
            return File.Exists(_path)
                ? JsonSerializer.Deserialize(File.ReadAllText(_path), SettingsJson.Default.AppSettings) ?? new AppSettings()
                : new AppSettings();
        }
        catch
        {
            return new AppSettings();
        }
    }

    public void Save(AppSettings settings)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(_path)!);
            File.WriteAllText(_path, JsonSerializer.Serialize(settings, SettingsJson.Default.AppSettings));
        }
        catch (Exception e)
        {
            AppLog.Warn("settings", $"Réglages non enregistrés : {e.Message}");
        }
    }
}

/// <summary>Choix automatique des pistes selon les langues préférées (pur, testé).</summary>
public static class TrackPreferences
{
    private static readonly Dictionary<string, string> Aliases = new()
    {
        ["fr"] = "fre", ["fra"] = "fre", ["fre"] = "fre", ["en"] = "eng", ["eng"] = "eng", ["es"] = "spa", ["spa"] = "spa",
        ["de"] = "ger", ["deu"] = "ger", ["ger"] = "ger", ["it"] = "ita", ["ita"] = "ita", ["pt"] = "por", ["por"] = "por",
        ["ja"] = "jpn", ["jpn"] = "jpn", ["ko"] = "kor", ["kor"] = "kor", ["zh"] = "chi", ["zho"] = "chi", ["chi"] = "chi",
        ["ru"] = "rus", ["rus"] = "rus", ["ar"] = "ara", ["ara"] = "ara", ["nl"] = "dut", ["nld"] = "dut", ["dut"] = "dut",
    };

    public static string? Normalize(string? code)
    {
        if (string.IsNullOrEmpty(code)) return null;
        var c = code.ToLowerInvariant().Split('-', '_')[0];
        return Aliases.TryGetValue(c, out var v) ? v : c;
    }

    /// <summary>
    /// (audio, sous-titres) à utiliser. Les valeurs du plan sont gardées quand aucune préférence ne
    /// s'applique (le serveur a déjà appliqué celles du compte Jellyfin).
    /// </summary>
    public static (int? Audio, int? Subtitle) Preferred(PlaybackPlan plan, AppSettings settings) =>
        Preferred(new TrackSet(plan.AudioTracks, plan.SubtitleTracks, plan.AudioIndex, plan.SubtitleIndex), settings);

    /// <summary>Même choix à partir des pistes de la fiche : demandé d'emblée au serveur (une seule requête PlaybackInfo).</summary>
    public static (int? Audio, int? Subtitle) Preferred(TrackSet tracks, AppSettings settings)
    {
        var audio = tracks.AudioIndex;
        if (Normalize(settings.AudioLanguage) is { } audioLang)
        {
            var matches = tracks.Audio.Where(t => Normalize(t.Language) == audioLang).ToList();
            if (matches.Count > 0 && matches.All(t => t.Index != audio))
                audio = (matches.FirstOrDefault(t => t.IsDefault) ?? matches[0]).Index;
        }

        var subLang = Normalize(settings.SubtitleLanguage);
        List<MediaTrack> InLang(IEnumerable<MediaTrack> tracks) =>
            subLang == null ? [.. tracks] : [.. tracks.Where(t => Normalize(t.Language) == subLang)];
        var subs = tracks.Subtitles;
        int? subtitle = settings.SubtitleMode switch
        {
            SubtitleMode.Server => tracks.SubtitleIndex,
            SubtitleMode.None => null,
            SubtitleMode.Always => (InLang(subs.Where(t => !t.IsForced)).FirstOrDefault() ?? InLang(subs).FirstOrDefault())?.Index
                                   ?? tracks.SubtitleIndex,
            _ => InLang(subs.Where(t => t.IsForced)).FirstOrDefault()?.Index,
        };
        return (audio, subtitle);
    }
}
