namespace OptiFin.Core.Media;

public enum LibrarySort { Title, DateAdded, PremiereDate, Rating, Runtime, Year }

public enum ResolutionFilter { Any, Hd, Uhd }

public static class LibrarySortExtensions
{
    public static string Label(this LibrarySort s) => s switch
    {
        LibrarySort.Title => "Titre",
        LibrarySort.DateAdded => "Date d’ajout",
        LibrarySort.PremiereDate => "Date de sortie",
        LibrarySort.Rating => "Note",
        LibrarySort.Runtime => "Durée",
        _ => "Année",
    };

    /// <summary>Sens par défaut : récent / meilleur d'abord, sauf le titre.</summary>
    public static bool DefaultDescending(this LibrarySort s) => s != LibrarySort.Title;

    /// <summary>Tri principal + départage par titre (ordre stable entre pages).</summary>
    public static string SortFields(this LibrarySort s) => s switch
    {
        LibrarySort.Title => "SortName",
        LibrarySort.DateAdded => "DateCreated,SortName",
        LibrarySort.PremiereDate => "PremiereDate,SortName",
        LibrarySort.Rating => "CommunityRating,SortName",
        LibrarySort.Runtime => "Runtime,SortName",
        _ => "ProductionYear,SortName",
    };
}

/// <summary>Requête de parcours d'une bibliothèque (immuable).</summary>
public sealed record LibraryQuery
{
    public string? ParentId { get; init; }
    public IReadOnlyList<MediaKind> Kinds { get; init; } = [];
    public bool Recursive { get; init; } = true;
    public LibrarySort Sort { get; init; } = LibrarySort.Title;
    public bool Descending { get; init; }

    /// <summary>null = tous, true = vus, false = non vus.</summary>
    public bool? Played { get; init; }
    public bool FavoritesOnly { get; init; }
    public IReadOnlyList<string> GenreIds { get; init; } = [];
    public IReadOnlyList<int> Years { get; init; } = [];
    public ResolutionFilter Resolution { get; init; }

    public int ActiveFilterCount =>
        (Played != null ? 1 : 0) + (FavoritesOnly ? 1 : 0) + (GenreIds.Count > 0 ? 1 : 0) + (Years.Count > 0 ? 1 : 0) +
        (Resolution != ResolutionFilter.Any ? 1 : 0);

    public static IReadOnlyList<MediaKind> DefaultKindsFor(LibraryType? type) => type switch
    {
        LibraryType.Movies => [MediaKind.Movie],
        LibraryType.TvShows => [MediaKind.Series],
        LibraryType.BoxSets => [MediaKind.BoxSet],
        LibraryType.Music => [MediaKind.MusicAlbum],
        LibraryType.MusicVideos => [MediaKind.MusicVideo],
        LibraryType.Playlists => [MediaKind.Playlist],
        _ => [],
    };

    public static bool RecursiveFor(LibraryType? type) =>
        type is not (LibraryType.HomeVideos or LibraryType.Photos or LibraryType.Folders or LibraryType.Unknown or null);

    public static LibraryQuery For(MediaItem library) => new()
    {
        ParentId = library.Id,
        Kinds = DefaultKindsFor(library.LibraryType),
        Recursive = RecursiveFor(library.LibraryType),
    };
}

public sealed record PageResult<T>(IReadOnlyList<T> Items, int Total);

public sealed record LibraryFilterOptions(IReadOnlyList<NamedRef> Genres, IReadOnlyList<int> Years);

/// <summary>Résultats de recherche groupés.</summary>
public sealed record SearchResults(
    IReadOnlyList<MediaItem> Movies,
    IReadOnlyList<MediaItem> Series,
    IReadOnlyList<MediaItem> Episodes,
    IReadOnlyList<MediaItem> People,
    IReadOnlyList<MediaItem> Others)
{
    public bool IsEmpty => Movies.Count + Series.Count + Episodes.Count + People.Count + Others.Count == 0;
}
