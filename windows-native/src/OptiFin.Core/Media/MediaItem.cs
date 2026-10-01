namespace OptiFin.Core.Media;

public enum MediaKind
{
    Movie, Series, Season, Episode, BoxSet, Folder, CollectionFolder, Person, MusicAlbum, MusicArtist, Audio,
    Playlist, Video, MusicVideo, Photo, PhotoAlbum, Trailer, TvChannel, Other,
}

public static class MediaKindExtensions
{
    /// <summary>Contenu vidéo lisible directement (bouton Lecture).</summary>
    public static bool IsPlayableVideo(this MediaKind k) =>
        k is MediaKind.Movie or MediaKind.Episode or MediaKind.Video or MediaKind.MusicVideo or MediaKind.Trailer;

    /// <summary>Format affiche 2:3 plutôt que paysage.</summary>
    public static bool PrefersPoster(this MediaKind k) =>
        k is MediaKind.Movie or MediaKind.Series or MediaKind.Season or MediaKind.BoxSet or MediaKind.Person or MediaKind.Playlist;

    public static string? ApiName(this MediaKind k) => k switch
    {
        MediaKind.Other => null,
        MediaKind.TvChannel => "TvChannel",
        _ => k.ToString(),
    };
}

public enum LibraryType { Movies, TvShows, Music, MusicVideos, HomeVideos, BoxSets, Books, Photos, LiveTv, Playlists, Folders, Unknown }

public enum ImageKind { Primary, Backdrop, Logo, Thumb, Banner, Art }

/// <summary>Référence d'image : élément, type, tag de cache, BlurHash.</summary>
public sealed record ImageRef(string ItemId, ImageKind Type, string Tag, string? BlurHash = null, int Index = 0);

public sealed record UserState(
    bool Played = false,
    bool Favorite = false,
    long PositionTicks = 0,
    double? PlayedPercentage = null,
    int? UnplayedCount = null)
{
    /// <summary>Progression 0..1 si une lecture est en cours.</summary>
    public double? Progress => PlayedPercentage is > 0 and < 100 ? PlayedPercentage / 100 : null;
}

public enum PersonKind { Actor, GuestStar, Director, Writer, Producer, Composer, Other }

public sealed record PersonCredit(string Id, string Name, string? Role, PersonKind Kind, ImageRef? Image);

public sealed record NamedRef(string Id, string Name);

public sealed record Trailer(Uri Url, string? Name);

public enum VideoRange { Sdr, Hlg, Hdr10, Hdr10Plus, DolbyVision }

public enum SpatialAudio { None, Atmos, DtsX }

/// <summary>Résumé technique d'un flux (badges de la fiche).</summary>
public sealed record StreamSummary(
    bool IsVideo,
    string Codec,
    int? Width = null,
    int? Height = null,
    VideoRange VideoRange = VideoRange.Sdr,
    int? BitDepth = null,
    string? Profile = null,
    int? Channels = null,
    SpatialAudio Spatial = SpatialAudio.None,
    string? Language = null,
    string? Title = null);

/// <summary>Élément Jellyfin tel que l'interface l'affiche (découplé des DTO du serveur).</summary>
public sealed record MediaItem
{
    public required string Id { get; init; }
    public required string Name { get; init; }
    public required MediaKind Kind { get; init; }
    public string? OriginalTitle { get; init; }
    public string? Overview { get; init; }
    public string? Tagline { get; init; }
    public int? Year { get; init; }
    public DateTimeOffset? PremiereDate { get; init; }
    public DateTimeOffset? EndDate { get; init; }
    public string? Status { get; init; }
    public long? RunTimeTicks { get; init; }
    public double? CommunityRating { get; init; }
    public double? CriticRating { get; init; }
    public string? OfficialRating { get; init; }
    public IReadOnlyList<NamedRef> Genres { get; init; } = [];
    public IReadOnlyList<NamedRef> Studios { get; init; } = [];
    public IReadOnlyList<PersonCredit> People { get; init; } = [];
    public IReadOnlyList<Trailer> Trailers { get; init; } = [];
    public int LocalTrailerCount { get; init; }
    public UserState User { get; init; } = new();
    public string? SeriesId { get; init; }
    public string? SeriesName { get; init; }
    public string? SeasonId { get; init; }
    public string? SeasonName { get; init; }
    public int? IndexNumber { get; init; }
    public int? ParentIndexNumber { get; init; }
    public int? ChildCount { get; init; }
    public LibraryType? LibraryType { get; init; }
    public IReadOnlyList<StreamSummary> Streams { get; init; } = [];
    public ImageRef? Primary { get; init; }
    public IReadOnlyList<ImageRef> Backdrops { get; init; } = [];
    public ImageRef? Logo { get; init; }
    public ImageRef? Thumb { get; init; }
    public ImageRef? ParentBackdrop { get; init; }
    public ImageRef? ParentThumb { get; init; }
    public ImageRef? SeriesPrimary { get; init; }
    public double? PrimaryAspectRatio { get; init; }
    public bool IsFolder { get; init; }

    public TimeSpan? Runtime => RunTimeTicks is { } t ? TimeSpan.FromTicks(t) : null;
    public TimeSpan ResumePosition => TimeSpan.FromTicks(User.PositionTicks);

    /// <summary>Image de fond : backdrop propre, sinon hérité, sinon vignette.</summary>
    public ImageRef? Backdrop => Backdrops.FirstOrDefault() ?? ParentBackdrop ?? Thumb ?? ParentThumb;

    /// <summary>Image 16:9 pour les cartes paysage.</summary>
    public ImageRef? Landscape => Kind switch
    {
        MediaKind.Episode or MediaKind.Video or MediaKind.MusicVideo => Primary ?? ParentThumb ?? ParentBackdrop,
        _ => Thumb ?? Backdrops.FirstOrDefault() ?? ParentThumb ?? ParentBackdrop ?? Primary,
    };

    /// <summary>Image 2:3 pour les cartes affiche (épisode → affiche de la série).</summary>
    public ImageRef? Poster => Kind == MediaKind.Episode ? SeriesPrimary ?? Primary : Primary;

    /// <summary>« S1 · É3 » pour un épisode.</summary>
    public string? EpisodeLabel
    {
        get
        {
            if (Kind != MediaKind.Episode) return null;
            if (ParentIndexNumber is null && IndexNumber is null) return null;
            if (ParentIndexNumber == 0) return IndexNumber is { } e ? $"Spécial {e}" : "Spécial";
            var parts = new List<string>();
            if (ParentIndexNumber is { } s) parts.Add($"S{s}");
            if (IndexNumber is { } n) parts.Add($"É{n}");
            return string.Join(" · ", parts);
        }
    }
}
