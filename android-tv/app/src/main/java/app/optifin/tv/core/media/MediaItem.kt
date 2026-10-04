package app.optifin.tv.core.media

import app.optifin.tv.core.api.BaseItemDto
import java.time.OffsetDateTime

enum class MediaKind {
    Movie, Series, Season, Episode, BoxSet, Folder, CollectionFolder, Person, MusicAlbum, MusicArtist, Audio,
    Playlist, Video, MusicVideo, Photo, PhotoAlbum, Trailer, TvChannel, Other;

    /** Contenu vidéo lisible directement (bouton Lecture). */
    val isPlayableVideo: Boolean get() = this == Movie || this == Episode || this == Video || this == MusicVideo || this == Trailer

    /** Format affiche 2:3 plutôt que paysage. */
    val prefersPoster: Boolean get() = this == Movie || this == Series || this == Season || this == BoxSet || this == Person || this == Playlist

    val apiName: String? get() = if (this == Other) null else name
}

enum class LibraryType { Movies, TvShows, Music, MusicVideos, HomeVideos, BoxSets, Books, Photos, LiveTv, Playlists, Folders, Unknown }

enum class ImageKind { Primary, Backdrop, Logo, Thumb, Banner, Art }

/** Référence d'image : élément, type, tag de cache, BlurHash. */
data class ImageRef(val itemId: String, val type: ImageKind, val tag: String, val blurHash: String? = null, val index: Int = 0)

data class UserState(
    val played: Boolean = false,
    val favorite: Boolean = false,
    val positionTicks: Long = 0,
    val playedPercentage: Double? = null,
    val unplayedCount: Int? = null,
) {
    /** Progression 0..1 si une lecture est en cours. */
    val progress: Double? get() = playedPercentage?.takeIf { it > 0 && it < 100 }?.div(100)
}

enum class PersonKind { Actor, GuestStar, Director, Writer, Producer, Composer, Other }

data class PersonCredit(val id: String, val name: String, val role: String?, val kind: PersonKind, val image: ImageRef?)

data class NamedRef(val id: String, val name: String)

data class Trailer(val url: String, val name: String?)

enum class VideoRange { Sdr, Hlg, Hdr10, Hdr10Plus, DolbyVision }

enum class SpatialAudio { None, Atmos, DtsX }

/** Résumé technique d'un flux (badges de la fiche). */
data class StreamSummary(
    val isVideo: Boolean,
    val codec: String,
    val width: Int? = null,
    val height: Int? = null,
    val videoRange: VideoRange = VideoRange.Sdr,
    val bitDepth: Int? = null,
    val profile: String? = null,
    val channels: Int? = null,
    val spatial: SpatialAudio = SpatialAudio.None,
    val language: String? = null,
    val title: String? = null,
)

/** Élément Jellyfin tel que l'interface l'affiche (découplé des DTO du serveur). */
data class MediaItem(
    val id: String,
    val name: String,
    val kind: MediaKind,
    val originalTitle: String? = null,
    val overview: String? = null,
    val tagline: String? = null,
    val year: Int? = null,
    val premiereDate: OffsetDateTime? = null,
    val endDate: OffsetDateTime? = null,
    val status: String? = null,
    val runTimeTicks: Long? = null,
    val communityRating: Double? = null,
    val criticRating: Double? = null,
    val officialRating: String? = null,
    val genres: List<NamedRef> = emptyList(),
    val studios: List<NamedRef> = emptyList(),
    val people: List<PersonCredit> = emptyList(),
    val trailers: List<Trailer> = emptyList(),
    val localTrailerCount: Int = 0,
    val user: UserState = UserState(),
    val seriesId: String? = null,
    val seriesName: String? = null,
    val seasonId: String? = null,
    val seasonName: String? = null,
    val indexNumber: Int? = null,
    val parentIndexNumber: Int? = null,
    val childCount: Int? = null,
    val libraryType: LibraryType? = null,
    val streams: List<StreamSummary> = emptyList(),
    val primary: ImageRef? = null,
    val backdrops: List<ImageRef> = emptyList(),
    val logo: ImageRef? = null,
    val thumb: ImageRef? = null,
    val parentBackdrop: ImageRef? = null,
    val parentThumb: ImageRef? = null,
    val seriesPrimary: ImageRef? = null,
    val primaryAspectRatio: Double? = null,
    val isFolder: Boolean = false,
) {
    val runtimeMs: Long? get() = runTimeTicks?.div(10_000)
    val resumeMs: Long get() = user.positionTicks / 10_000

    /** Image de fond : backdrop propre, sinon hérité, sinon vignette. */
    val backdrop: ImageRef? get() = backdrops.firstOrNull() ?: parentBackdrop ?: thumb ?: parentThumb

    /** Image 16:9 pour les cartes paysage. */
    val landscape: ImageRef?
        get() = when (kind) {
            MediaKind.Episode, MediaKind.Video, MediaKind.MusicVideo -> primary ?: parentThumb ?: parentBackdrop
            else -> thumb ?: backdrops.firstOrNull() ?: parentThumb ?: parentBackdrop ?: primary
        }

    /** Image 2:3 pour les cartes affiche (épisode → affiche de la série). */
    val poster: ImageRef? get() = if (kind == MediaKind.Episode) seriesPrimary ?: primary else primary

    /** « S1 · É3 » pour un épisode. */
    val episodeLabel: String?
        get() {
            if (kind != MediaKind.Episode) return null
            if (parentIndexNumber == null && indexNumber == null) return null
            if (parentIndexNumber == 0) return indexNumber?.let { "Spécial $it" } ?: "Spécial"
            return listOfNotNull(parentIndexNumber?.let { "S$it" }, indexNumber?.let { "É$it" }).joinToString(" · ")
        }
}

/** BaseItemDto → MediaItem (tolérant aux champs absents : le serveur ne renvoie que les Fields demandés). */
object MediaMapper {
    fun fromDto(dto: BaseItemDto): MediaItem {
        val blur = dto.imageBlurHashes
        fun blurOf(map: Map<String, String>?, tag: String?) = if (tag != null && map != null) map[tag] else null
        fun own(kind: ImageKind, key: String, blurs: Map<String, String>?): ImageRef? =
            dto.imageTags?.get(key)?.let { ImageRef(dto.id, kind, it, blurOf(blurs, it)) }

        val backdrops = (dto.backdropImageTags ?: emptyList()).mapIndexed { i, tag ->
            ImageRef(dto.id, ImageKind.Backdrop, tag, blurOf(blur?.backdrop, tag), i)
        }
        val parentBackdropTag = dto.parentBackdropImageTags?.firstOrNull()
        val parentBackdrop = if (dto.parentBackdropItemId != null && parentBackdropTag != null) {
            ImageRef(dto.parentBackdropItemId, ImageKind.Backdrop, parentBackdropTag, blurOf(blur?.backdrop, parentBackdropTag))
        } else null
        val logo = own(ImageKind.Logo, "Logo", blur?.logo)
            ?: if (dto.parentLogoItemId != null && dto.parentLogoImageTag != null) {
                ImageRef(dto.parentLogoItemId, ImageKind.Logo, dto.parentLogoImageTag, blurOf(blur?.logo, dto.parentLogoImageTag))
            } else null
        val parentThumb = when {
            dto.parentThumbItemId != null && dto.parentThumbImageTag != null ->
                ImageRef(dto.parentThumbItemId, ImageKind.Thumb, dto.parentThumbImageTag, blurOf(blur?.thumb, dto.parentThumbImageTag))
            dto.seriesId != null && dto.seriesThumbImageTag != null -> ImageRef(dto.seriesId, ImageKind.Thumb, dto.seriesThumbImageTag)
            else -> null
        }
        val seriesPrimary = if (dto.seriesId != null && dto.seriesPrimaryImageTag != null) {
            ImageRef(dto.seriesId, ImageKind.Primary, dto.seriesPrimaryImageTag, blurOf(blur?.primary, dto.seriesPrimaryImageTag))
        } else null
        val ud = dto.userData
        return MediaItem(
            id = dto.id,
            name = dto.name ?: "",
            kind = kindOf(dto.type),
            originalTitle = dto.originalTitle,
            overview = clean(dto.overview),
            tagline = dto.taglines?.firstOrNull(),
            year = dto.productionYear,
            premiereDate = date(dto.premiereDate),
            endDate = date(dto.endDate),
            status = dto.status,
            runTimeTicks = dto.runTimeTicks ?: dto.cumulativeRunTimeTicks,
            communityRating = dto.communityRating?.toDouble(),
            criticRating = dto.criticRating?.toDouble(),
            officialRating = dto.officialRating,
            genres = dto.genreItems.orEmpty().mapNotNull { g -> if (g.id != null && g.name != null) NamedRef(g.id, g.name) else null },
            studios = dto.studios.orEmpty().mapNotNull { g -> if (g.id != null && g.name != null) NamedRef(g.id, g.name) else null },
            people = dto.people.orEmpty().map { p ->
                PersonCredit(p.id, p.name ?: "", p.role?.takeIf { it.isNotEmpty() }, personKindOf(p.type),
                    p.primaryImageTag?.let { ImageRef(p.id, ImageKind.Primary, it) })
            },
            trailers = dto.remoteTrailers.orEmpty().mapNotNull { t -> t.url?.takeIf { it.startsWith("http") }?.let { Trailer(it, t.name) } },
            localTrailerCount = dto.localTrailerCount ?: 0,
            user = UserState(ud?.played ?: false, ud?.isFavorite ?: false, ud?.playbackPositionTicks ?: 0, ud?.playedPercentage, ud?.unplayedItemCount),
            seriesId = dto.seriesId,
            seriesName = dto.seriesName,
            seasonId = dto.seasonId,
            seasonName = dto.seasonName,
            indexNumber = dto.indexNumber,
            parentIndexNumber = dto.parentIndexNumber,
            childCount = dto.childCount ?: dto.recursiveItemCount,
            libraryType = libraryTypeOf(dto.collectionType),
            streams = streams(dto),
            primary = own(ImageKind.Primary, "Primary", blur?.primary),
            backdrops = backdrops,
            logo = logo,
            thumb = own(ImageKind.Thumb, "Thumb", blur?.thumb),
            parentBackdrop = parentBackdrop,
            parentThumb = parentThumb,
            seriesPrimary = seriesPrimary,
            primaryAspectRatio = dto.primaryImageAspectRatio,
            isFolder = dto.isFolder ?: false,
        )
    }

    private fun date(value: String?): OffsetDateTime? = value?.let { runCatching { OffsetDateTime.parse(it) }.getOrNull() }

    fun kindOf(type: String?): MediaKind = when (type) {
        "Movie" -> MediaKind.Movie
        "Series" -> MediaKind.Series
        "Season" -> MediaKind.Season
        "Episode" -> MediaKind.Episode
        "BoxSet" -> MediaKind.BoxSet
        "Folder", "AggregateFolder" -> MediaKind.Folder
        "CollectionFolder", "UserView" -> MediaKind.CollectionFolder
        "Person" -> MediaKind.Person
        "MusicAlbum" -> MediaKind.MusicAlbum
        "MusicArtist" -> MediaKind.MusicArtist
        "Audio", "AudioBook" -> MediaKind.Audio
        "Playlist" -> MediaKind.Playlist
        "Video" -> MediaKind.Video
        "MusicVideo" -> MediaKind.MusicVideo
        "Photo" -> MediaKind.Photo
        "PhotoAlbum" -> MediaKind.PhotoAlbum
        "Trailer" -> MediaKind.Trailer
        "TvChannel", "LiveTvChannel" -> MediaKind.TvChannel
        else -> MediaKind.Other
    }

    fun libraryTypeOf(type: String?): LibraryType? = when (type?.lowercase()) {
        null -> null
        "movies" -> LibraryType.Movies
        "tvshows" -> LibraryType.TvShows
        "music" -> LibraryType.Music
        "musicvideos" -> LibraryType.MusicVideos
        "homevideos" -> LibraryType.HomeVideos
        "boxsets" -> LibraryType.BoxSets
        "books" -> LibraryType.Books
        "photos" -> LibraryType.Photos
        "livetv" -> LibraryType.LiveTv
        "playlists" -> LibraryType.Playlists
        "folders" -> LibraryType.Folders
        else -> LibraryType.Unknown
    }

    private fun personKindOf(t: String?) = when (t) {
        "Actor" -> PersonKind.Actor
        "GuestStar" -> PersonKind.GuestStar
        "Director" -> PersonKind.Director
        "Writer" -> PersonKind.Writer
        "Producer" -> PersonKind.Producer
        "Composer" -> PersonKind.Composer
        else -> PersonKind.Other
    }

    fun videoRangeOf(t: String?): VideoRange = when (t) {
        "DOVI", "DOVIWithHDR10", "DOVIWithHLG", "DOVIWithSDR", "DOVIWithEL", "DOVIWithHDR10Plus", "DOVIWithELHDR10Plus" -> VideoRange.DolbyVision
        "HDR10Plus" -> VideoRange.Hdr10Plus
        "HDR10" -> VideoRange.Hdr10
        "HLG" -> VideoRange.Hlg
        else -> VideoRange.Sdr
    }

    private fun streams(dto: BaseItemDto): List<StreamSummary> {
        val streams = dto.mediaSources?.firstOrNull()?.mediaStreams ?: dto.mediaStreams ?: emptyList()
        return streams.mapNotNull { s ->
            val codec = (s.codec ?: "").lowercase()
            when (s.type) {
                "Video" -> StreamSummary(true, codec, s.width, s.height, videoRangeOf(s.videoRangeType), s.bitDepth)
                "Audio" -> StreamSummary(
                    false, codec, profile = s.profile, channels = s.channels,
                    spatial = when (s.audioSpatialFormat) {
                        "DolbyAtmos" -> SpatialAudio.Atmos
                        "DTSX" -> SpatialAudio.DtsX
                        else -> SpatialAudio.None
                    },
                    language = s.language, title = s.displayTitle,
                )
                else -> null
            }
        }
    }

    private val breakPattern = Regex("<br\\s*/?>", RegexOption.IGNORE_CASE)
    private val tagPattern = Regex("<[^>]+>")

    /** Retire les balises HTML parfois présentes dans les synopsis. */
    fun clean(text: String?): String? {
        if (text == null) return null
        val cleaned = tagPattern.replace(breakPattern.replace(text, "\n"), "")
            .replace("&amp;", "&").replace("&quot;", "\"").replace("&#39;", "'").trim()
        return cleaned.ifEmpty { null }
    }
}
