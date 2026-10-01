using OptiFin.Core.Api;

namespace OptiFin.Core.Media;

using Query = List<KeyValuePair<string, string?>>;

/// <summary>Accès aux contenus de l'utilisateur courant. Toutes les erreurs sortent en <see cref="ApiException"/>.</summary>
public sealed class MediaRepository(JellyfinClient api, string userId)
{
    /// <summary>Champs des cartes (rangées, grilles) : image, titre, progression.</summary>
    private const string CardFields = "PrimaryImageAspectRatio,ChildCount";
    private const string FeaturedFields = "Overview,Genres,PrimaryImageAspectRatio";
    private const string EpisodeFields = "Overview,PrimaryImageAspectRatio";
    private const string DetailFields =
        "Overview,Genres,Studios,People,Taglines,RemoteTrailers,MediaSources,MediaStreams,ChildCount,OriginalTitle,PrimaryImageAspectRatio,ExternalUrls";
    private const string CardImages = "Primary,Backdrop,Thumb,Logo";

    public JellyfinClient Api => api;
    public string UserId => userId;

    private static IReadOnlyList<MediaItem> Map(IEnumerable<BaseItemDto>? items) => [.. (items ?? []).Select(MediaMapper.FromDto)];

    private Task<BaseItemDtoQueryResult> Items(Query q, CancellationToken ct) =>
        api.GetAsync($"Users/{userId}/Items", JellyfinJson.Default.BaseItemDtoQueryResult, q, ct);

    // ---------------------------------------------------------------- Accueil

    public async Task<IReadOnlyList<BaseItemDto>> UserViewsRawAsync(CancellationToken ct = default) =>
        (await api.GetAsync($"Users/{userId}/Views", JellyfinJson.Default.BaseItemDtoQueryResult, ct: ct)).Items ?? [];

    public async Task<IReadOnlyList<MediaItem>> UserViewsAsync(CancellationToken ct = default) => Map(await UserViewsRawAsync(ct));

    public async Task<IReadOnlyList<BaseItemDto>> ResumeRawAsync(int limit = 16, CancellationToken ct = default) =>
        (await api.GetAsync($"Users/{userId}/Items/Resume", JellyfinJson.Default.BaseItemDtoQueryResult,
        [
            new("Limit", limit.ToString()), new("MediaTypes", "Video"), new("Fields", CardFields),
            new("EnableImageTypes", CardImages), new("ImageTypeLimit", "1"), new("EnableTotalRecordCount", "false"),
        ], ct)).Items ?? [];

    public async Task<IReadOnlyList<BaseItemDto>> NextUpRawAsync(int limit = 16, CancellationToken ct = default) =>
        (await api.GetAsync("Shows/NextUp", JellyfinJson.Default.BaseItemDtoQueryResult,
        [
            new("UserId", userId), new("Limit", limit.ToString()), new("Fields", CardFields), new("EnableImageTypes", CardImages),
            new("ImageTypeLimit", "1"), new("EnableTotalRecordCount", "false"), new("EnableResumable", "false"),
            new("EnableRewatching", "false"),
        ], ct)).Items ?? [];

    public Task<List<BaseItemDto>> LatestRawAsync(string parentId, int limit = 16, CancellationToken ct = default) =>
        api.GetAsync($"Users/{userId}/Items/Latest", JellyfinJson.Default.ListBaseItemDto,
        [
            new("ParentId", parentId), new("Limit", limit.ToString()), new("GroupItems", "true"), new("Fields", CardFields),
            new("EnableImageTypes", CardImages), new("ImageTypeLimit", "1"),
        ], ct);

    /// <summary>Carrousel : films et séries non vus, au hasard, avec fond et synopsis.</summary>
    public async Task<IReadOnlyList<BaseItemDto>> FeaturedRawAsync(int limit = 12, CancellationToken ct = default) =>
        (await Items(
        [
            new("Recursive", "true"), new("IncludeItemTypes", "Movie,Series"), new("ImageTypes", "Backdrop"),
            new("Filters", "IsUnplayed"), new("HasOverview", "true"), new("SortBy", "Random"), new("Limit", limit.ToString()),
            new("Fields", FeaturedFields), new("EnableImageTypes", "Backdrop,Logo,Primary"), new("ImageTypeLimit", "1"),
            new("EnableTotalRecordCount", "false"),
        ], ct)).Items ?? [];

    public async Task<IReadOnlyList<BaseItemDto>> FavoritesRawAsync(int limit = 20, CancellationToken ct = default) =>
        (await Items(
        [
            new("Recursive", "true"), new("IsFavorite", "true"), new("IncludeItemTypes", "Movie,Series,Episode,BoxSet"),
            new("SortBy", "DatePlayed,SortName"), new("SortOrder", "Descending"), new("Limit", limit.ToString()),
            new("Fields", CardFields), new("EnableImageTypes", CardImages), new("ImageTypeLimit", "1"),
            new("EnableTotalRecordCount", "false"),
        ], ct)).Items ?? [];

    // ---------------------------------------------------------------- Fiches

    public async Task<BaseItemDto> ItemRawAsync(string id, CancellationToken ct = default)
    {
        var r = await Items([new("Ids", id), new("Fields", DetailFields), new("EnableTotalRecordCount", "false")], ct);
        return r.Items?.FirstOrDefault() ?? throw new ApiException(ApiErrorKind.Unexpected, "Élément introuvable");
    }

    public async Task<MediaItem> ItemAsync(string id, CancellationToken ct = default) => MediaMapper.FromDto(await ItemRawAsync(id, ct));

    /// <summary>Personne : /Items/{id} renvoie la biographie complète.</summary>
    public async Task<MediaItem> PersonAsync(string id, CancellationToken ct = default) =>
        MediaMapper.FromDto(await api.GetAsync($"Users/{userId}/Items/{id}", JellyfinJson.Default.BaseItemDto, ct: ct));

    public async Task<IReadOnlyList<MediaItem>> SeasonsAsync(string seriesId, CancellationToken ct = default) =>
        Map((await api.GetAsync($"Shows/{seriesId}/Seasons", JellyfinJson.Default.BaseItemDtoQueryResult,
            [new("UserId", userId), new("Fields", CardFields), new("EnableImageTypes", CardImages)], ct)).Items);

    public async Task<IReadOnlyList<MediaItem>> EpisodesAsync(string seriesId, string seasonId, CancellationToken ct = default) =>
        Map((await api.GetAsync($"Shows/{seriesId}/Episodes", JellyfinJson.Default.BaseItemDtoQueryResult,
            [new("UserId", userId), new("SeasonId", seasonId), new("Fields", EpisodeFields), new("EnableImageTypes", "Primary,Thumb")],
            ct)).Items);

    /// <summary>Épisode à reprendre / suivant d'une série (bouton Lecture de la fiche série).</summary>
    public async Task<MediaItem?> NextUpForAsync(string seriesId, CancellationToken ct = default)
    {
        var r = await api.GetAsync("Shows/NextUp", JellyfinJson.Default.BaseItemDtoQueryResult,
        [
            new("UserId", userId), new("SeriesId", seriesId), new("Limit", "1"), new("Fields", EpisodeFields),
            new("EnableResumable", "true"), new("EnableTotalRecordCount", "false"),
        ], ct);
        return r.Items?.FirstOrDefault() is { } dto ? MediaMapper.FromDto(dto) : null;
    }

    /// <summary>Épisode qui suit <paramref name="episode"/> dans la série (null si dernier).</summary>
    public async Task<MediaItem?> NextEpisodeAsync(MediaItem episode, CancellationToken ct = default)
    {
        if (episode.SeriesId is null) return null;
        var r = await api.GetAsync($"Shows/{episode.SeriesId}/Episodes", JellyfinJson.Default.BaseItemDtoQueryResult,
        [
            new("UserId", userId), new("StartItemId", episode.Id), new("Limit", "2"), new("Fields", EpisodeFields),
            new("EnableImageTypes", CardImages), new("ImageTypeLimit", "1"),
        ], ct);
        var items = r.Items ?? [];
        return items.Count >= 2 && items[0].Id == episode.Id ? MediaMapper.FromDto(items[1]) : null;
    }

    public async Task<IReadOnlyList<MediaItem>> SimilarAsync(string id, int limit = 16, CancellationToken ct = default) =>
        Map((await api.GetAsync($"Items/{id}/Similar", JellyfinJson.Default.BaseItemDtoQueryResult,
            [new("UserId", userId), new("Limit", limit.ToString()), new("Fields", CardFields)], ct)).Items);

    public async Task<IReadOnlyList<MediaItem>> ChildrenAsync(string parentId, int limit = 200, CancellationToken ct = default) =>
        Map((await Items(
        [
            new("ParentId", parentId), new("SortBy", "PremiereDate,SortName"), new("Limit", limit.ToString()),
            new("Fields", CardFields), new("EnableImageTypes", CardImages), new("ImageTypeLimit", "1"),
        ], ct)).Items);

    /// <summary>Filmographie d'une personne.</summary>
    public async Task<IReadOnlyList<MediaItem>> CreditsAsync(string personId, CancellationToken ct = default) =>
        Map((await Items(
        [
            new("PersonIds", personId), new("Recursive", "true"), new("IncludeItemTypes", "Movie,Series"),
            new("SortBy", "PremiereDate,SortName"), new("SortOrder", "Descending"), new("Fields", CardFields),
            new("EnableImageTypes", CardImages), new("ImageTypeLimit", "1"),
        ], ct)).Items);

    // ---------------------------------------------------------------- Bibliothèques

    private Query Filters(LibraryQuery q)
    {
        var query = new Query { new("ParentId", q.ParentId), new("Recursive", q.Recursive ? "true" : "false") };
        if (q.Kinds.Count > 0) query.Add(new("IncludeItemTypes", string.Join(',', q.Kinds.Select(k => k.ApiName()).OfType<string>())));
        if (q.Played is { } played) query.Add(new("IsPlayed", played ? "true" : "false"));
        if (q.FavoritesOnly) query.Add(new("IsFavorite", "true"));
        if (q.GenreIds.Count > 0) query.Add(new("GenreIds", string.Join('|', q.GenreIds)));
        if (q.Years.Count > 0) query.Add(new("Years", string.Join(',', q.Years)));
        if (q.Resolution == ResolutionFilter.Hd) query.Add(new("IsHd", "true"));
        if (q.Resolution == ResolutionFilter.Uhd) query.Add(new("Is4K", "true"));
        return query;
    }

    public async Task<PageResult<MediaItem>> PageAsync(LibraryQuery q, int startIndex, int limit, CancellationToken ct = default)
    {
        var query = Filters(q);
        query.AddRange(
        [
            new("SortBy", q.Sort.SortFields()), new("SortOrder", q.Descending ? "Descending" : "Ascending"),
            new("StartIndex", startIndex.ToString()), new("Limit", limit.ToString()), new("Fields", CardFields),
            new("EnableImageTypes", CardImages), new("ImageTypeLimit", "1"), new("EnableTotalRecordCount", "true"),
        ]);
        var r = await Items(query, ct);
        return new PageResult<MediaItem>(Map(r.Items), r.TotalRecordCount ?? r.Items?.Count ?? 0);
    }

    public async Task<LibraryFilterOptions> FilterOptionsAsync(LibraryQuery q, CancellationToken ct = default)
    {
        var kinds = q.Kinds.Count > 0 ? string.Join(',', q.Kinds.Select(k => k.ApiName()).OfType<string>()) : null;
        var filters = api.GetAsync("Items/Filters2", JellyfinJson.Default.QueryFilters,
            [new("UserId", userId), new("ParentId", q.ParentId), new("IncludeItemTypes", kinds)], ct);
        var legacy = api.GetAsync("Items/Filters", JellyfinJson.Default.QueryFiltersLegacy,
            [new("UserId", userId), new("ParentId", q.ParentId), new("IncludeItemTypes", kinds)], ct);
        await Task.WhenAll(filters, legacy);
        return new LibraryFilterOptions(
            [.. (filters.Result.Genres ?? []).Where(g => g.Id != null && g.Name != null).Select(g => new NamedRef(g.Id!, g.Name!))
                .OrderBy(g => g.Name, StringComparer.CurrentCultureIgnoreCase)],
            [.. (legacy.Result.Years ?? []).OrderDescending()]);
    }

    // ---------------------------------------------------------------- Recherche

    public async Task<SearchResults> SearchAsync(string term, CancellationToken ct = default)
    {
        Task<IReadOnlyList<MediaItem>> ByKind(string kinds) => Items(
        [
            new("SearchTerm", term), new("Recursive", "true"), new("IncludeItemTypes", kinds), new("Limit", "24"),
            new("Fields", CardFields), new("EnableImageTypes", CardImages), new("ImageTypeLimit", "1"),
            new("EnableTotalRecordCount", "false"),
        ], ct).ContinueWith(t => Map(t.Result.Items), ct, TaskContinuationOptions.OnlyOnRanToCompletion, TaskScheduler.Default);

        var people = api.GetAsync("Persons", JellyfinJson.Default.BaseItemDtoQueryResult,
            [new("SearchTerm", term), new("UserId", userId), new("Limit", "20"), new("EnableImageTypes", "Primary")], ct);
        var movies = ByKind("Movie");
        var series = ByKind("Series");
        var episodes = ByKind("Episode");
        var others = ByKind("BoxSet,Video,MusicVideo");
        await Task.WhenAll(movies, series, episodes, others, people);
        return new SearchResults(movies.Result, series.Result, episodes.Result, Map(people.Result.Items), others.Result);
    }

    // ---------------------------------------------------------------- Actions

    public async Task<UserState> SetFavoriteAsync(string id, bool favorite, CancellationToken ct = default)
    {
        var path = $"Users/{userId}/FavoriteItems/{id}";
        var d = favorite
            ? await api.PostAsync(path, null, JellyfinJson.Default.UserItemDataDto, ct: ct)
            : await api.DeleteAsync(path, JellyfinJson.Default.UserItemDataDto, ct);
        return StateOf(d);
    }

    public async Task<UserState> SetPlayedAsync(string id, bool played, CancellationToken ct = default)
    {
        var path = $"Users/{userId}/PlayedItems/{id}";
        var d = played
            ? await api.PostAsync(path, null, JellyfinJson.Default.UserItemDataDto, ct: ct)
            : await api.DeleteAsync(path, JellyfinJson.Default.UserItemDataDto, ct);
        return StateOf(d);
    }

    private static UserState StateOf(UserItemDataDto d) =>
        new(d.Played ?? false, d.IsFavorite ?? false, d.PlaybackPositionTicks ?? 0, d.PlayedPercentage, d.UnplayedItemCount);
}
