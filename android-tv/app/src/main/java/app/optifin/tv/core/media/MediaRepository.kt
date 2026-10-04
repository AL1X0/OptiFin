package app.optifin.tv.core.media

import app.optifin.tv.core.AppLog
import app.optifin.tv.core.api.ApiErrorKind
import app.optifin.tv.core.api.ApiException
import app.optifin.tv.core.api.BaseItemDto
import app.optifin.tv.core.api.BaseItemDtoQueryResult
import app.optifin.tv.core.api.JellyfinClient
import app.optifin.tv.core.api.JellyfinJson
import app.optifin.tv.core.api.Query
import app.optifin.tv.core.api.QueryFilters
import app.optifin.tv.core.api.QueryFiltersLegacy
import app.optifin.tv.core.api.Urls
import app.optifin.tv.core.api.UserItemDataDto
import java.io.File
import java.text.Collator
import java.util.Locale
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.serialization.Serializable

/**
 * URL d'images redimensionnées par le serveur : largeur arrondie au palier supérieur (meilleur
 * taux de cache). Images publiques : aucun jeton dans l'URL.
 */
class ImageUrls(private val baseUrl: String) {
    fun image(r: ImageRef, width: Int, quality: Int = 90): String {
        val path = if (r.type == ImageKind.Backdrop) "Items/${r.itemId}/Images/${r.type}/${r.index}" else "Items/${r.itemId}/Images/${r.type}"
        return Urls.resolve(baseUrl, path, listOf(
            "maxWidth" to bucket(width).toString(), "quality" to quality.toString(), "format" to "Webp", "tag" to r.tag,
        )).toString()
    }

    fun maybe(r: ImageRef?, width: Int, quality: Int = 90): String? = r?.let { image(it, width, quality) }

    fun userAvatar(userId: String, width: Int, tag: String?): String =
        Urls.resolve(baseUrl, "Users/$userId/Images/Primary", listOf(
            "maxWidth" to bucket(width).toString(), "quality" to "90", "format" to "Webp", "tag" to tag,
        )).toString()

    fun chapter(itemId: String, index: Int, tag: String?, width: Int): String =
        Urls.resolve(baseUrl, "Items/$itemId/Images/Chapter/$index", listOf(
            "maxWidth" to bucket(width).toString(), "quality" to "85", "format" to "Webp", "tag" to tag,
        )).toString()

    /** Planche trickplay (vignettes de la barre de progression). */
    fun trickplayTile(itemId: String, width: Int, index: Int, mediaSourceId: String): String =
        Urls.resolve(baseUrl, "Videos/$itemId/Trickplay/$width/$index.jpg", listOf("mediaSourceId" to mediaSourceId)).toString()

    companion object {
        val BUCKETS = intArrayOf(120, 180, 240, 320, 480, 640, 800, 1080, 1280, 1920, 2560, 3840)
        fun bucket(width: Int): Int = BUCKETS.firstOrNull { it >= width } ?: BUCKETS.last()
    }
}

enum class LibrarySort(val label: String, val fields: String) {
    Title("Titre", "SortName"),
    DateAdded("Date d’ajout", "DateCreated,SortName"),
    PremiereDate("Date de sortie", "PremiereDate,SortName"),
    Rating("Note", "CommunityRating,SortName"),
    Runtime("Durée", "Runtime,SortName"),
    Year("Année", "ProductionYear,SortName");

    /** Sens par défaut : récent / meilleur d'abord, sauf le titre. */
    val defaultDescending: Boolean get() = this != Title
}

enum class ResolutionFilter(val label: String) { Any("Toutes"), Hd("HD"), Uhd("4K") }

/** Requête de parcours d'une bibliothèque (immuable). */
data class LibraryQuery(
    val parentId: String? = null,
    val kinds: List<MediaKind> = emptyList(),
    val recursive: Boolean = true,
    val sort: LibrarySort = LibrarySort.Title,
    val descending: Boolean = false,
    /** null = tous, true = vus, false = non vus. */
    val played: Boolean? = null,
    val favoritesOnly: Boolean = false,
    val genreIds: List<String> = emptyList(),
    val years: List<Int> = emptyList(),
    val resolution: ResolutionFilter = ResolutionFilter.Any,
) {
    val activeFilterCount: Int
        get() = (if (played != null) 1 else 0) + (if (favoritesOnly) 1 else 0) + (if (genreIds.isNotEmpty()) 1 else 0) +
            (if (years.isNotEmpty()) 1 else 0) + (if (resolution != ResolutionFilter.Any) 1 else 0)

    companion object {
        fun defaultKindsFor(type: LibraryType?): List<MediaKind> = when (type) {
            LibraryType.Movies -> listOf(MediaKind.Movie)
            LibraryType.TvShows -> listOf(MediaKind.Series)
            LibraryType.BoxSets -> listOf(MediaKind.BoxSet)
            LibraryType.Music -> listOf(MediaKind.MusicAlbum)
            LibraryType.MusicVideos -> listOf(MediaKind.MusicVideo)
            LibraryType.Playlists -> listOf(MediaKind.Playlist)
            else -> emptyList()
        }

        fun recursiveFor(type: LibraryType?): Boolean =
            type != null && type !in setOf(LibraryType.HomeVideos, LibraryType.Photos, LibraryType.Folders, LibraryType.Unknown)

        fun forLibrary(library: MediaItem) = LibraryQuery(
            parentId = library.id,
            kinds = defaultKindsFor(library.libraryType),
            recursive = recursiveFor(library.libraryType),
        )
    }
}

data class PageResult<T>(val items: List<T>, val total: Int)

data class LibraryFilterOptions(val genres: List<NamedRef>, val years: List<Int>)

/** Résultats de recherche groupés. */
data class SearchResults(
    val movies: List<MediaItem>,
    val series: List<MediaItem>,
    val episodes: List<MediaItem>,
    val people: List<MediaItem>,
    val others: List<MediaItem>,
) {
    val isEmpty: Boolean get() = movies.isEmpty() && series.isEmpty() && episodes.isEmpty() && people.isEmpty() && others.isEmpty()
}

/** Accès aux contenus de l'utilisateur courant ; erreurs en [ApiException]. */
class MediaRepository(val api: JellyfinClient, val userId: String) {
    private companion object {
        const val CARD_FIELDS = "PrimaryImageAspectRatio,ChildCount,Overview"
        const val FEATURED_FIELDS = "Overview,Genres,PrimaryImageAspectRatio"
        const val EPISODE_FIELDS = "Overview,PrimaryImageAspectRatio"
        const val DETAIL_FIELDS =
            "Overview,Genres,Studios,People,Taglines,RemoteTrailers,MediaSources,MediaStreams,ChildCount,OriginalTitle,PrimaryImageAspectRatio,ExternalUrls"
        const val CARD_IMAGES = "Primary,Backdrop,Thumb,Logo"
    }

    private fun map(items: List<BaseItemDto>?) = items.orEmpty().map(MediaMapper::fromDto)

    private suspend fun items(q: Query): BaseItemDtoQueryResult = api.get("Users/$userId/Items", q)

    // ---------------------------------------------------------------- Accueil

    suspend fun userViewsRaw(): List<BaseItemDto> = api.get<BaseItemDtoQueryResult>("Users/$userId/Views").items.orEmpty()
    suspend fun userViews(): List<MediaItem> = map(userViewsRaw())

    suspend fun resumeRaw(limit: Int = 20): List<BaseItemDto> = api.get<BaseItemDtoQueryResult>(
        "Users/$userId/Items/Resume",
        listOf("Limit" to "$limit", "MediaTypes" to "Video", "Fields" to CARD_FIELDS, "EnableImageTypes" to CARD_IMAGES,
            "ImageTypeLimit" to "1", "EnableTotalRecordCount" to "false"),
    ).items.orEmpty()

    suspend fun nextUpRaw(limit: Int = 20): List<BaseItemDto> = api.get<BaseItemDtoQueryResult>(
        "Shows/NextUp",
        listOf("UserId" to userId, "Limit" to "$limit", "Fields" to CARD_FIELDS, "EnableImageTypes" to CARD_IMAGES,
            "ImageTypeLimit" to "1", "EnableTotalRecordCount" to "false", "EnableResumable" to "false", "EnableRewatching" to "false"),
    ).items.orEmpty()

    suspend fun latestRaw(parentId: String, limit: Int = 20): List<BaseItemDto> = api.get(
        "Users/$userId/Items/Latest",
        listOf("ParentId" to parentId, "Limit" to "$limit", "GroupItems" to "true", "Fields" to CARD_FIELDS,
            "EnableImageTypes" to CARD_IMAGES, "ImageTypeLimit" to "1"),
    )

    /** Carrousel : films et séries non vus, au hasard, avec fond et synopsis. */
    suspend fun featuredRaw(limit: Int = 12): List<BaseItemDto> = items(listOf(
        "Recursive" to "true", "IncludeItemTypes" to "Movie,Series", "ImageTypes" to "Backdrop", "Filters" to "IsUnplayed",
        "HasOverview" to "true", "SortBy" to "Random", "Limit" to "$limit", "Fields" to FEATURED_FIELDS,
        "EnableImageTypes" to "Backdrop,Logo,Primary", "ImageTypeLimit" to "1", "EnableTotalRecordCount" to "false",
    )).items.orEmpty()

    suspend fun favoritesRaw(limit: Int = 24): List<BaseItemDto> = items(listOf(
        "Recursive" to "true", "IsFavorite" to "true", "IncludeItemTypes" to "Movie,Series,Episode,BoxSet",
        "SortBy" to "DatePlayed,SortName", "SortOrder" to "Descending", "Limit" to "$limit", "Fields" to CARD_FIELDS,
        "EnableImageTypes" to CARD_IMAGES, "ImageTypeLimit" to "1", "EnableTotalRecordCount" to "false",
    )).items.orEmpty()

    // ---------------------------------------------------------------- Fiches

    suspend fun itemRaw(id: String): BaseItemDto =
        items(listOf("Ids" to id, "Fields" to DETAIL_FIELDS, "EnableTotalRecordCount" to "false")).items?.firstOrNull()
            ?: throw ApiException(ApiErrorKind.NotFound, "Élément introuvable")

    suspend fun item(id: String): MediaItem = MediaMapper.fromDto(itemRaw(id))

    /** Personne : /Items/{id} renvoie la biographie complète. */
    suspend fun person(id: String): MediaItem = MediaMapper.fromDto(api.get("Users/$userId/Items/$id"))

    suspend fun seasons(seriesId: String): List<MediaItem> = map(api.get<BaseItemDtoQueryResult>(
        "Shows/$seriesId/Seasons", listOf("UserId" to userId, "Fields" to CARD_FIELDS, "EnableImageTypes" to CARD_IMAGES),
    ).items)

    suspend fun episodes(seriesId: String, seasonId: String): List<MediaItem> = map(api.get<BaseItemDtoQueryResult>(
        "Shows/$seriesId/Episodes",
        listOf("UserId" to userId, "SeasonId" to seasonId, "Fields" to EPISODE_FIELDS, "EnableImageTypes" to "Primary,Thumb"),
    ).items)

    /** Épisode à reprendre / suivant d'une série (bouton Lecture de la fiche série). */
    suspend fun nextUpFor(seriesId: String): MediaItem? = api.get<BaseItemDtoQueryResult>(
        "Shows/NextUp",
        listOf("UserId" to userId, "SeriesId" to seriesId, "Limit" to "1", "Fields" to EPISODE_FIELDS,
            "EnableResumable" to "true", "EnableTotalRecordCount" to "false"),
    ).items?.firstOrNull()?.let(MediaMapper::fromDto)

    /** Épisode qui suit [episode] dans la série (null si dernier). */
    suspend fun nextEpisode(episode: MediaItem): MediaItem? {
        val seriesId = episode.seriesId ?: return null
        val items = api.get<BaseItemDtoQueryResult>(
            "Shows/$seriesId/Episodes",
            listOf("UserId" to userId, "StartItemId" to episode.id, "Limit" to "2", "Fields" to EPISODE_FIELDS,
                "EnableImageTypes" to CARD_IMAGES, "ImageTypeLimit" to "1"),
        ).items.orEmpty()
        return if (items.size >= 2 && items[0].id == episode.id) MediaMapper.fromDto(items[1]) else null
    }

    suspend fun similar(id: String, limit: Int = 20): List<MediaItem> = map(api.get<BaseItemDtoQueryResult>(
        "Items/$id/Similar", listOf("UserId" to userId, "Limit" to "$limit", "Fields" to CARD_FIELDS),
    ).items)

    suspend fun children(parentId: String, limit: Int = 300): List<MediaItem> = map(items(listOf(
        "ParentId" to parentId, "SortBy" to "PremiereDate,SortName", "Limit" to "$limit", "Fields" to CARD_FIELDS,
        "EnableImageTypes" to CARD_IMAGES, "ImageTypeLimit" to "1",
    )).items)

    /** Filmographie d'une personne. */
    suspend fun credits(personId: String): List<MediaItem> = map(items(listOf(
        "PersonIds" to personId, "Recursive" to "true", "IncludeItemTypes" to "Movie,Series", "SortBy" to "PremiereDate,SortName",
        "SortOrder" to "Descending", "Fields" to CARD_FIELDS, "EnableImageTypes" to CARD_IMAGES, "ImageTypeLimit" to "1",
    )).items)

    /** Bandes-annonces locales (fichiers du serveur). */
    suspend fun localTrailers(id: String): List<MediaItem> = map(api.get<List<BaseItemDto>>("Users/$userId/Items/$id/LocalTrailers"))

    // ---------------------------------------------------------------- Bibliothèques

    private fun filters(q: LibraryQuery): MutableList<Pair<String, String?>> {
        val query = mutableListOf<Pair<String, String?>>("ParentId" to q.parentId, "Recursive" to q.recursive.toString())
        if (q.kinds.isNotEmpty()) query.add("IncludeItemTypes" to q.kinds.mapNotNull { it.apiName }.joinToString(","))
        q.played?.let { query.add("IsPlayed" to it.toString()) }
        if (q.favoritesOnly) query.add("IsFavorite" to "true")
        if (q.genreIds.isNotEmpty()) query.add("GenreIds" to q.genreIds.joinToString("|"))
        if (q.years.isNotEmpty()) query.add("Years" to q.years.joinToString(","))
        if (q.resolution == ResolutionFilter.Hd) query.add("IsHd" to "true")
        if (q.resolution == ResolutionFilter.Uhd) query.add("Is4K" to "true")
        return query
    }

    suspend fun page(q: LibraryQuery, startIndex: Int, limit: Int): PageResult<MediaItem> {
        val query = filters(q)
        query += listOf(
            "SortBy" to q.sort.fields, "SortOrder" to if (q.descending) "Descending" else "Ascending",
            "StartIndex" to "$startIndex", "Limit" to "$limit", "Fields" to CARD_FIELDS, "EnableImageTypes" to CARD_IMAGES,
            "ImageTypeLimit" to "1", "EnableTotalRecordCount" to "true",
        )
        val r = items(query)
        return PageResult(map(r.items), r.totalRecordCount ?: r.items?.size ?: 0)
    }

    /** Position du premier titre commençant par cette lettre (tri par titre croissant) ; « # » = début. */
    suspend fun indexOfLetter(q: LibraryQuery, letter: String): Int {
        if (letter == "#") return 0
        val query = filters(q)
        query += listOf("NameLessThan" to letter, "Limit" to "0", "EnableImages" to "false", "EnableTotalRecordCount" to "true")
        return items(query).totalRecordCount ?: 0
    }

    suspend fun filterOptions(q: LibraryQuery): LibraryFilterOptions = coroutineScope {
        val kinds = q.kinds.mapNotNull { it.apiName }.joinToString(",").ifEmpty { null }
        val base = listOf("UserId" to userId, "ParentId" to q.parentId, "IncludeItemTypes" to kinds)
        val filters = async { api.get<QueryFilters>("Items/Filters2", base) }
        val legacy = async { api.get<QueryFiltersLegacy>("Items/Filters", base) }
        val collator = Collator.getInstance(Locale.FRANCE)
        LibraryFilterOptions(
            filters.await().genres.orEmpty().mapNotNull { g -> if (g.id != null && g.name != null) NamedRef(g.id, g.name) else null }
                .sortedWith { a, b -> collator.compare(a.name, b.name) },
            legacy.await().years.orEmpty().sortedDescending(),
        )
    }

    // ---------------------------------------------------------------- Recherche

    suspend fun search(term: String): SearchResults = coroutineScope {
        suspend fun byKind(kinds: String) = map(items(listOf(
            "SearchTerm" to term, "Recursive" to "true", "IncludeItemTypes" to kinds, "Limit" to "24", "Fields" to CARD_FIELDS,
            "EnableImageTypes" to CARD_IMAGES, "ImageTypeLimit" to "1", "EnableTotalRecordCount" to "false",
        )).items)
        val people = async {
            map(api.get<BaseItemDtoQueryResult>("Persons",
                listOf("SearchTerm" to term, "UserId" to userId, "Limit" to "20", "EnableImageTypes" to "Primary")).items)
        }
        val movies = async { byKind("Movie") }
        val series = async { byKind("Series") }
        val episodes = async { byKind("Episode") }
        val others = async { byKind("BoxSet,Video,MusicVideo") }
        SearchResults(movies.await(), series.await(), episodes.await(), people.await(), others.await())
    }

    // ---------------------------------------------------------------- Actions

    suspend fun setFavorite(id: String, favorite: Boolean): UserState {
        val path = "Users/$userId/FavoriteItems/$id"
        val d: UserItemDataDto = if (favorite) api.post(path) else api.delete(path)
        return stateOf(d)
    }

    suspend fun setPlayed(id: String, played: Boolean): UserState {
        val path = "Users/$userId/PlayedItems/$id"
        val d: UserItemDataDto = if (played) api.post(path) else api.delete(path)
        return stateOf(d)
    }

    private fun stateOf(d: UserItemDataDto) =
        UserState(d.played ?: false, d.isFavorite ?: false, d.playbackPositionTicks ?: 0, d.playedPercentage, d.unplayedItemCount)
}

/** Une rangée de l'accueil. */
data class HomeSection(val id: String, val title: String, val items: List<MediaItem>, val landscape: Boolean, val libraryId: String? = null)

/** Accueil prêt à afficher. */
data class HomeData(val featured: List<MediaItem>, val sections: List<HomeSection>, val libraries: List<MediaItem>, val fromCache: Boolean) {
    val isEmpty: Boolean get() = featured.isEmpty() && sections.isEmpty()
}

@Serializable
data class HomeSnapshot(
    val v: Int = 1,
    val views: List<BaseItemDto> = emptyList(),
    val featured: List<BaseItemDto> = emptyList(),
    val resume: List<BaseItemDto> = emptyList(),
    val nextUp: List<BaseItemDto> = emptyList(),
    val latest: Map<String, List<BaseItemDto>> = emptyMap(),
    val favorites: List<BaseItemDto> = emptyList(),
)

/**
 * Accueil : affiché d'abord depuis le cache (instantané), puis rafraîchi depuis le serveur. La
 * sélection « à la une » affichée depuis le cache est conservée (rien ne change sous les yeux).
 */
class HomeRepository(private val media: MediaRepository, accountId: String, cacheDirectory: File) {
    private val cacheFile = File(cacheDirectory, "home-${accountId.filter(Char::isLetterOrDigit)}.json")
    private val latestTypes = setOf("movies", "tvshows", "music", "musicvideos", "homevideos")

    fun watch(): Flow<HomeData> = flow {
        val cached = readCache()
        if (cached != null) emit(build(cached, fromCache = true))
        val fresh = try {
            fetch()
        } catch (e: ApiException) {
            if (cached == null) throw e
            AppLog.w("home", "Accueil en cache (serveur indisponible : ${e.message})")
            return@flow
        }
        var shown = fresh
        if (cached != null && cached.featured.isNotEmpty()) {
            val started = startedIds(fresh)
            val kept = cached.featured.filter { it.id !in started }
            if (kept.isNotEmpty()) shown = fresh.copy(featured = kept)
        }
        emit(build(shown, fromCache = false))
        writeCache(fresh)
    }

    private fun startedIds(s: HomeSnapshot): Set<String> = s.resume.map { it.id }.toSet() + s.nextUp.mapNotNull { it.seriesId }

    suspend fun fetch(): HomeSnapshot = coroutineScope {
        val views = media.userViewsRaw()
        val latestViews = views.filter { (it.collectionType?.lowercase() ?: "") in latestTypes }
        val featured = async { media.featuredRaw() }
        val resume = async { media.resumeRaw() }
        val nextUp = async { media.nextUpRaw() }
        val favorites = async { runCatching { media.favoritesRaw() }.getOrDefault(emptyList()) }
        // Une bibliothèque en échec ne fait pas tomber l'accueil entier.
        val latest = latestViews.map { v -> async { v.id to runCatching { media.latestRaw(v.id) }.getOrDefault(emptyList()) } }
        val snapshot = HomeSnapshot(
            views = views, resume = resume.await(), nextUp = nextUp.await(), favorites = favorites.await(),
            latest = latest.map { it.await() }.toMap(),
        )
        val started = startedIds(snapshot)
        snapshot.copy(featured = featured.await().filter { it.id !in started }.take(8))
    }

    /** Reprendre → À suivre → Ajouts récents (par bibliothèque) → Favoris. Rangées vides omises. */
    fun build(s: HomeSnapshot, fromCache: Boolean): HomeData {
        fun map(items: List<BaseItemDto>) = items.map(MediaMapper::fromDto)
        val libraries = map(s.views)
        val resume = map(s.resume)
        val resumeIds = resume.map { it.id }.toSet()
        val nextUp = map(s.nextUp.filter { it.id !in resumeIds })
        val sections = mutableListOf<HomeSection>()
        if (resume.isNotEmpty()) sections += HomeSection("resume", "Reprendre", resume, landscape = true)
        if (nextUp.isNotEmpty()) sections += HomeSection("nextup", "À suivre", nextUp, landscape = true)
        for (lib in libraries) {
            val items = s.latest[lib.id].orEmpty()
            if (items.isEmpty()) continue
            sections += HomeSection("latest-${lib.id}", "Ajouts récents · ${lib.name}", map(items), landscape = false, libraryId = lib.id)
        }
        if (s.favorites.isNotEmpty()) sections += HomeSection("favorites", "Favoris", map(s.favorites), landscape = false)
        val featured = map(s.featured).filter { it.backdrops.isNotEmpty() }
        return HomeData(featured, sections, libraries, fromCache)
    }

    private fun readCache(): HomeSnapshot? = try {
        if (cacheFile.exists()) JellyfinJson.decodeFromString(HomeSnapshot.serializer(), cacheFile.readText()).takeIf { it.v == 1 } else null
    } catch (e: Exception) {
        null
    }

    private fun writeCache(s: HomeSnapshot) {
        try {
            cacheFile.parentFile?.mkdirs()
            cacheFile.writeText(JellyfinJson.encodeToString(HomeSnapshot.serializer(), s))
        } catch (e: Exception) {
            AppLog.w("home", "Cache de l'accueil non écrit : ${e.message}")
        }
    }

    fun clearCache() {
        cacheFile.delete()
    }
}

