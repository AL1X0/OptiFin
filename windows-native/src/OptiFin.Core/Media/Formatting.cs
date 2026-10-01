namespace OptiFin.Core.Media;

/// <summary>Badges qualité d'une fiche : résolution, dynamique, audio, canaux (un par catégorie).</summary>
public static class QualityBadges
{
    public static IReadOnlyList<string> For(IReadOnlyList<StreamSummary> streams)
    {
        var video = streams.FirstOrDefault(s => s.IsVideo);
        var audios = streams.Where(s => !s.IsVideo).ToList();
        var badges = new List<string>();
        if (video != null)
        {
            if (ResolutionLabel(video.Width, video.Height) is { } res) badges.Add(res);
            switch (video.VideoRange)
            {
                case VideoRange.DolbyVision: badges.Add("Dolby Vision"); break;
                case VideoRange.Hdr10Plus: badges.Add("HDR10+"); break;
                case VideoRange.Hdr10: badges.Add("HDR10"); break;
                case VideoRange.Hlg: badges.Add("HLG"); break;
            }
        }
        if (BestAudio(audios) is { } audio) badges.Add(audio);
        var channels = audios.Count == 0 ? 0 : audios.Max(a => a.Channels ?? 0);
        if (channels == 6) badges.Add("5.1");
        else if (channels == 8) badges.Add("7.1");
        return badges;
    }

    /// <summary>4K / 1080p / 720p / SD, en tolérant les formats recadrés (2.39:1).</summary>
    public static string? ResolutionLabel(int? width, int? height)
    {
        if (width is not > 0 || height is not > 0) return null;
        if (width >= 3200 || height >= 2000) return "4K";
        if (width >= 1800 || height >= 1000) return "1080p";
        if (width >= 1200 || height >= 700) return "720p";
        return "SD";
    }

    private static readonly string[] Ranking = ["Atmos", "DTS:X", "TrueHD", "DTS-HD MA", "DTS", "Dolby Digital+", "Dolby Digital"];

    private static string? BestAudio(IEnumerable<StreamSummary> audios)
    {
        string? best = null;
        foreach (var a in audios)
        {
            var label = AudioLabel(a);
            if (label != null && (best == null || Array.IndexOf(Ranking, label) < Array.IndexOf(Ranking, best))) best = label;
        }
        return best;
    }

    public static string? AudioLabel(StreamSummary a)
    {
        if (a.Spatial == SpatialAudio.Atmos) return "Atmos";
        if (a.Spatial == SpatialAudio.DtsX) return "DTS:X";
        var profile = (a.Profile ?? "").ToLowerInvariant();
        return a.Codec switch
        {
            "truehd" or "mlp" => "TrueHD",
            "dts" or "dca" when profile.Contains("ma") || profile.Contains("hd") => "DTS-HD MA",
            "dts" or "dca" => "DTS",
            "eac3" => "Dolby Digital+",
            "ac3" => "Dolby Digital",
            _ => null,
        };
    }
}

/// <summary>Mise en forme des métadonnées (mêmes règles que sur iPhone et Android).</summary>
public static class MediaFormat
{
    private static readonly System.Globalization.CultureInfo French = System.Globalization.CultureInfo.GetCultureInfo("fr-FR");

    /// <summary>« 2 h 14 min », « 48 min » ; null si moins d'une minute.</summary>
    public static string? Duration(TimeSpan? d)
    {
        if (d is not { } v || (int)v.TotalMinutes <= 0) return null;
        var h = (int)v.TotalHours;
        var m = (int)v.TotalMinutes % 60;
        if (h == 0) return $"{m} min";
        return m == 0 ? $"{h} h" : $"{h} h {m:00} min";
    }

    /// <summary>« 1:02:03 » / « 12:34 ».</summary>
    public static string Clock(TimeSpan d)
    {
        if (d < TimeSpan.Zero) d = TimeSpan.Zero;
        var h = (int)d.TotalHours;
        return h > 0 ? $"{h}:{d.Minutes:00}:{d.Seconds:00}" : $"{d.Minutes}:{d.Seconds:00}";
    }

    /// <summary>Années d'une série : « 2016 – 2022 », « 2019 – » (en cours).</summary>
    public static string? Years(MediaItem item)
    {
        var start = item.Year ?? item.PremiereDate?.Year;
        if (start is null) return null;
        if (item.Kind != MediaKind.Series) return start.ToString();
        if (item.Status == "Continuing") return $"{start} –";
        var end = item.EndDate?.Year;
        return end is null || end == start ? start.ToString() : $"{start} – {end}";
    }

    public static string? Rating(double? r) => r is > 0 ? r.Value.ToString("0.0", French) : null;

    /// <summary>« 2021 · 2 h 35 min · 12 · ★ 8,1 ».</summary>
    public static IReadOnlyList<string> MetadataLine(MediaItem item)
    {
        var parts = new List<string>();
        if (Years(item) is { } y) parts.Add(y);
        if (item.Kind == MediaKind.Series && item.ChildCount is { } c)
            parts.Add($"{c} saison{(c > 1 ? "s" : "")}");
        else if (Duration(item.Runtime) is { } d)
            parts.Add(d);
        if (!string.IsNullOrEmpty(item.OfficialRating)) parts.Add(item.OfficialRating!);
        if (Rating(item.CommunityRating) is { } r) parts.Add($"★ {r}");
        return parts;
    }

    /// <summary>« 1 h 12 min restantes ».</summary>
    public static string? Remaining(MediaItem item)
    {
        if (item.Runtime is not { } total || item.User.PositionTicks <= 0) return null;
        return Duration(total - item.ResumePosition) is { } label ? $"{label} restantes" : null;
    }
}
