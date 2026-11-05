using OptiFin.Core.Localization;

namespace OptiFin.Core.Playback;

public enum PlayMethod { DirectPlay, DirectStream, Transcode }

public static class PlayMethodExtensions
{
    public static string ApiName(this PlayMethod m) => m.ToString();

    public static string Label(this PlayMethod m) => m switch
    {
        PlayMethod.DirectPlay => L.T("Lecture directe"),
        PlayMethod.DirectStream => "Remux",
        _ => L.T("Transcodage"),
    };
}

public enum TrackType { Audio, Subtitle }

/// <summary>Piste audio ou de sous-titres d'une source.</summary>
public sealed record MediaTrack(
    int Index,
    TrackType Type,
    string Label,
    string? Language = null,
    string? Codec = null,
    bool IsDefault = false,
    bool IsForced = false,
    bool IsExternal = false,
    bool IsTextBased = true,
    string? DeliveryUrl = null,
    int? Channels = null);

/// <summary>Pistes d'une source et pistes retenues par défaut (fiche ou plan de lecture).</summary>
public sealed record TrackSet(IReadOnlyList<MediaTrack> Audio, IReadOnlyList<MediaTrack> Subtitles, int? AudioIndex, int? SubtitleIndex);

/// <summary>Comment lire un élément : URL du flux, pistes, mode choisi par le serveur.</summary>
public sealed record PlaybackPlan
{
    public required string ItemId { get; init; }
    public required string MediaSourceId { get; init; }
    public string? PlaySessionId { get; init; }
    public required PlayMethod Method { get; init; }
    public required Uri StreamUrl { get; init; }
    public IReadOnlyList<MediaTrack> AudioTracks { get; init; } = [];
    public IReadOnlyList<MediaTrack> SubtitleTracks { get; init; } = [];
    public int? AudioIndex { get; init; }
    public int? SubtitleIndex { get; init; }
    public string? Container { get; init; }
    public long? Bitrate { get; init; }
    public string? VideoCodec { get; init; }
    public string? VideoRangeType { get; init; }
    public TimeSpan Start { get; init; }
    public TimeSpan? Runtime { get; init; }

    public MediaTrack? CurrentAudio => AudioTracks.FirstOrDefault(t => t.Index == AudioIndex);
    public MediaTrack? CurrentSubtitle => SubtitleTracks.FirstOrDefault(t => t.Index == SubtitleIndex);

    /// <summary>
    /// Rang mpv d'une piste intégrée (1 = première piste de ce type dans le fichier). Les pistes
    /// externes (fichiers à côté) sont ajoutées à part ; null si la piste n'est pas intégrée.
    /// </summary>
    public int? MpvId(MediaTrack track)
    {
        if (track.IsExternal) return null;
        var list = track.Type == TrackType.Audio ? AudioTracks : SubtitleTracks;
        var rank = 0;
        foreach (var t in list.Where(t => !t.IsExternal).OrderBy(t => t.Index))
        {
            rank++;
            if (t.Index == track.Index) return rank;
        }
        return null;
    }
}

public enum SegmentType { Intro, Recap, Preview, Commercial, Outro }

public sealed record MediaSegment(SegmentType Type, TimeSpan Start, TimeSpan End)
{
    public string SkipLabel => Type switch
    {
        SegmentType.Intro => L.T("Passer l’intro"),
        SegmentType.Recap => L.T("Passer le récapitulatif"),
        SegmentType.Preview => L.T("Passer l’aperçu"),
        SegmentType.Commercial => L.T("Passer la publicité"),
        _ => L.T("Passer le générique"),
    };

    /// <summary>Trop court pour mériter un bouton (moins de 3 s).</summary>
    public bool IsSkippable => End - Start >= TimeSpan.FromSeconds(3);

    public bool Contains(TimeSpan position) => position >= Start && position < End;
}

public sealed record Chapter(int Index, TimeSpan Start, string Name, string? ImageTag);

/// <summary>
/// Vignettes d'aperçu d'une vidéo (trickplay) : planches JPEG de <see cref="TileWidth"/> × <see cref="TileHeight"/>
/// images de <see cref="Width"/> × <see cref="Height"/> pixels, une toutes les <see cref="Interval"/>.
/// </summary>
public sealed record TrickplayManifest(int Width, int Height, int TileWidth, int TileHeight, int ThumbnailCount, TimeSpan Interval)
{
    /// <summary>Planche, colonne et ligne de la vignette à afficher pour une position.</summary>
    public (int Sheet, int Column, int Row) TileAt(TimeSpan position)
    {
        var last = Math.Max(0, ThumbnailCount - 1);
        var index = Math.Clamp((long)(position.TotalMilliseconds / Math.Max(1, Interval.TotalMilliseconds)), 0, last);
        var perSheet = TileWidth * TileHeight;
        var inSheet = (int)(index % perSheet);
        return ((int)(index / perSheet), inSheet % TileWidth, inSheet / TileWidth);
    }
}

/// <summary>Compléments d'une lecture (facultatifs : absents du serveur → listes vides).</summary>
public sealed record PlaybackExtras(
    IReadOnlyList<Chapter> Chapters,
    IReadOnlyList<MediaSegment> Segments,
    Media.MediaItem? NextEpisode,
    TrickplayManifest? Trickplay = null)
{
    public static readonly PlaybackExtras Empty = new([], [], null);

    public Chapter? ChapterAt(TimeSpan position) => Chapters.LastOrDefault(c => c.Start <= position);

    /// <summary>
    /// Segment à proposer de passer : pas dans sa dernière seconde, et pas le générique de fin
    /// quand un épisode suivant existe (la carte « Épisode suivant » le remplace).
    /// </summary>
    public MediaSegment? SkippableAt(TimeSpan position)
    {
        foreach (var s in Segments)
        {
            if (!s.IsSkippable || !s.Contains(position)) continue;
            if (s.End - position < TimeSpan.FromSeconds(1)) continue;
            if (s.Type == SegmentType.Outro && NextEpisode != null) continue;
            return s;
        }
        return null;
    }

    /// <summary>
    /// Moment de proposer l'épisode suivant : début du générique s'il est connu, sinon 30 s avant
    /// la fin (jamais avant la moitié de l'épisode).
    /// </summary>
    public TimeSpan? UpNextAt(TimeSpan duration)
    {
        if (NextEpisode is null || duration <= TimeSpan.Zero) return null;
        var outro = Segments.FirstOrDefault(s => s.Type == SegmentType.Outro && s.End >= duration * 0.8);
        var at = outro?.Start ?? duration - TimeSpan.FromSeconds(30);
        return at < duration / 2 ? duration / 2 : at;
    }
}

/// <summary>Sous-titre trouvé en ligne par un fournisseur du serveur (OpenSubtitles…).</summary>
public sealed record RemoteSubtitle(string Id, string Name, string? Provider, string? Format, int? Downloads, double? Rating, bool HashMatch, bool HearingImpaired, bool Forced)
{
    public string Details => string.Join(" · ", new[]
    {
        Provider,
        Format?.ToUpperInvariant(),
        Downloads is > 0 and var d ? L.F("{0} téléchargements", d) : null,
        HashMatch ? L.T("correspond au fichier") : null,
        HearingImpaired ? "malentendants" : null,
        Forced ? L.T("forcés") : null,
    }.Where(x => !string.IsNullOrEmpty(x)));

    /// <summary>Résultats du serveur, les plus sûrs d'abord (correspondance exacte, puis popularité).</summary>
    public static IReadOnlyList<RemoteSubtitle> FromJson(System.Text.Json.JsonElement list)
    {
        if (list.ValueKind != System.Text.Json.JsonValueKind.Array) return [];
        string? S(System.Text.Json.JsonElement e, string n) =>
            e.TryGetProperty(n, out var v) && v.ValueKind == System.Text.Json.JsonValueKind.String ? v.GetString() : null;
        double? D(System.Text.Json.JsonElement e, string n) =>
            e.TryGetProperty(n, out var v) && v.ValueKind == System.Text.Json.JsonValueKind.Number ? v.GetDouble() : null;
        bool B(System.Text.Json.JsonElement e, string n) =>
            e.TryGetProperty(n, out var v) && v.ValueKind == System.Text.Json.JsonValueKind.True;
        return [.. list.EnumerateArray()
            .Where(e => !string.IsNullOrEmpty(S(e, "Id")))
            .Select(e => new RemoteSubtitle(
                S(e, "Id")!,
                S(e, "Name")?.Trim() is { Length: > 0 } name ? name : L.F("Sous-titre {0}", S(e, "Id")),
                S(e, "ProviderName"), S(e, "Format"), (int?)D(e, "DownloadCount"), D(e, "CommunityRating"),
                B(e, "IsHashMatch"), B(e, "HearingImpaired"), B(e, "Forced")))
            .OrderByDescending(r => r.HashMatch)
            .ThenByDescending(r => r.Downloads ?? 0)];
    }
}
