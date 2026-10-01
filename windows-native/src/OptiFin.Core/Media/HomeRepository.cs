using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Text.Json.Serialization;
using OptiFin.Core.Api;
using OptiFin.Core.Logging;

namespace OptiFin.Core.Media;

/// <summary>Données brutes de l'accueil, sérialisables pour le cache disque.</summary>
public sealed class HomeSnapshot
{
    public int V { get; set; } = 1;
    public List<BaseItemDto> Views { get; set; } = [];
    public List<BaseItemDto> Featured { get; set; } = [];
    public List<BaseItemDto> Resume { get; set; } = [];
    public List<BaseItemDto> NextUp { get; set; } = [];
    public Dictionary<string, List<BaseItemDto>> Latest { get; set; } = [];
    public List<BaseItemDto> Favorites { get; set; } = [];
}

[JsonSourceGenerationOptions(DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull)]
[JsonSerializable(typeof(HomeSnapshot))]
internal sealed partial class HomeJson : JsonSerializerContext;

/// <summary>Une rangée de l'accueil.</summary>
public sealed record HomeSection(string Title, IReadOnlyList<MediaItem> Items, bool Landscape, string? LibraryId = null);

/// <summary>Accueil prêt à afficher.</summary>
public sealed record HomeData(IReadOnlyList<MediaItem> Featured, IReadOnlyList<HomeSection> Sections,
    IReadOnlyList<MediaItem> Libraries, bool FromCache);

/// <summary>
/// Accueil : affiché d'abord depuis le cache (instantané), puis rafraîchi depuis le serveur. Hors
/// ligne, l'accueil en cache reste utilisable. La sélection « à la une » affichée depuis le cache
/// est conservée pour cette ouverture (rien ne change sous les yeux de l'utilisateur).
/// </summary>
public sealed class HomeRepository(MediaRepository media, string accountId, string? cacheDirectory = null)
{
    private readonly string _cachePath = Path.Combine(cacheDirectory ?? Path.Combine(AppLog.Directory, "cache"),
        $"home-{string.Concat(accountId.Where(char.IsLetterOrDigit))}.json");

    private static readonly HashSet<string> LatestLibraryTypes = ["movies", "tvshows", "music", "musicvideos", "homevideos"];

    public async IAsyncEnumerable<HomeData> WatchAsync([EnumeratorCancellation] CancellationToken ct = default)
    {
        var cached = ReadCache();
        if (cached != null) yield return Build(cached, fromCache: true);

        HomeSnapshot? fresh = null;
        Exception? failure = null;
        try
        {
            fresh = await FetchAsync(ct);
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            failure = e;
        }
        if (fresh is null)
        {
            if (cached is null) throw failure ?? new ApiException(ApiErrorKind.Unexpected);
            AppLog.Warn("home", $"Accueil en cache (serveur indisponible : {failure?.Message})");
            yield break;
        }
        var shown = fresh;
        if (cached is { Featured.Count: > 0 })
        {
            var started = StartedIds(fresh);
            var kept = cached.Featured.Where(i => !started.Contains(i.Id)).ToList();
            if (kept.Count > 0) shown = Clone(fresh, kept);
        }
        yield return Build(shown, fromCache: false);
        WriteCache(fresh);
    }

    private static HashSet<string> StartedIds(HomeSnapshot s) =>
        [.. s.Resume.Select(i => i.Id), .. s.NextUp.Select(i => i.SeriesId).OfType<string>()];

    private static HomeSnapshot Clone(HomeSnapshot s, List<BaseItemDto> featured) => new()
    {
        Views = s.Views, Featured = featured, Resume = s.Resume, NextUp = s.NextUp, Latest = s.Latest, Favorites = s.Favorites,
    };

    public async Task<HomeSnapshot> FetchAsync(CancellationToken ct = default)
    {
        var views = await media.UserViewsRawAsync(ct);
        var latestViews = views.Where(v => LatestLibraryTypes.Contains(v.CollectionType?.ToLowerInvariant() ?? "")).ToList();
        var featured = media.FeaturedRawAsync(ct: ct);
        var resume = media.ResumeRawAsync(ct: ct);
        var nextUp = media.NextUpRawAsync(ct: ct);
        var favorites = media.FavoritesRawAsync(ct: ct);
        // Une bibliothèque en échec ne fait pas tomber l'accueil entier.
        var latest = latestViews.Select(async v =>
        {
            try
            {
                return (v.Id, Items: await media.LatestRawAsync(v.Id, ct: ct));
            }
            catch (ApiException)
            {
                return (v.Id, Items: new List<BaseItemDto>());
            }
        }).ToList();
        await Task.WhenAll(featured, resume, nextUp, favorites);
        var latestResults = await Task.WhenAll(latest);

        var snapshot = new HomeSnapshot
        {
            Views = [.. views],
            Resume = [.. resume.Result],
            NextUp = [.. nextUp.Result],
            Favorites = [.. favorites.Result],
            Latest = latestResults.ToDictionary(r => r.Id, r => r.Items),
        };
        // Déjà commencés : leur place est dans « Reprendre » / « À suivre », pas en vitrine.
        var started = StartedIds(snapshot);
        snapshot.Featured = [.. featured.Result.Where(i => !started.Contains(i.Id)).Take(8)];
        return snapshot;
    }

    /// <summary>
    /// Ordre : Reprendre → À suivre → Ajouts récents (par bibliothèque, ordre du serveur) → Favoris.
    /// Rangées vides omises ; « À suivre » exclut les épisodes déjà dans « Reprendre ».
    /// </summary>
    public static HomeData Build(HomeSnapshot s, bool fromCache)
    {
        static IReadOnlyList<MediaItem> Map(IEnumerable<BaseItemDto> items) => [.. items.Select(MediaMapper.FromDto)];
        var libraries = Map(s.Views);
        var resume = Map(s.Resume);
        var resumeIds = resume.Select(i => i.Id).ToHashSet();
        var nextUp = Map(s.NextUp.Where(i => !resumeIds.Contains(i.Id)));
        var sections = new List<HomeSection>();
        if (resume.Count > 0) sections.Add(new HomeSection("Reprendre", resume, Landscape: true));
        if (nextUp.Count > 0) sections.Add(new HomeSection("À suivre", nextUp, Landscape: true));
        foreach (var lib in libraries)
        {
            if (!s.Latest.TryGetValue(lib.Id, out var items) || items.Count == 0) continue;
            sections.Add(new HomeSection($"Ajouts récents · {lib.Name}", Map(items), Landscape: false, lib.Id));
        }
        if (s.Favorites.Count > 0) sections.Add(new HomeSection("Favoris", Map(s.Favorites), Landscape: false));
        // À la une : seulement les titres avec une image de fond.
        var featured = Map(s.Featured).Where(i => i.Backdrops.Count > 0).ToList();
        return new HomeData(featured, sections, libraries, fromCache);
    }

    private HomeSnapshot? ReadCache()
    {
        try
        {
            if (!File.Exists(_cachePath)) return null;
            var s = JsonSerializer.Deserialize(File.ReadAllText(_cachePath), HomeJson.Default.HomeSnapshot);
            return s?.V == 1 ? s : null;
        }
        catch
        {
            return null; // cache corrompu ou ancien format : ignoré
        }
    }

    private void WriteCache(HomeSnapshot s)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(_cachePath)!);
            File.WriteAllText(_cachePath, JsonSerializer.Serialize(s, HomeJson.Default.HomeSnapshot));
        }
        catch (Exception e)
        {
            AppLog.Warn("home", $"Cache de l'accueil non écrit : {e.Message}");
        }
    }
}
