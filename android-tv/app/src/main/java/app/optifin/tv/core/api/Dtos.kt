package app.optifin.tv.core.api

import kotlinx.serialization.Serializable

// Sous-ensemble de l'API Jellyfin (10.9+) utilisé par OptiFin. Noms en camelCase côté Kotlin,
// PascalCase dans le JSON (voir JellyfinJson) ; énumérations gardées en chaînes.

@Serializable
data class PublicSystemInfo(val id: String? = null, val serverName: String? = null, val version: String? = null, val productName: String? = null)

@Serializable
data class UserDto(val id: String = "", val name: String? = null, val primaryImageTag: String? = null, val hasPassword: Boolean? = null)

@Serializable
data class AuthenticationResult(val user: UserDto? = null, val accessToken: String? = null)

@Serializable
data class QuickConnectResult(val authenticated: Boolean? = null, val secret: String? = null, val code: String? = null)

@Serializable
data class NameGuidPair(val id: String? = null, val name: String? = null)

@Serializable
data class BaseItemPerson(
    val id: String = "",
    val name: String? = null,
    val role: String? = null,
    val type: String? = null,
    val primaryImageTag: String? = null,
)

@Serializable
data class MediaUrl(val url: String? = null, val name: String? = null)

@Serializable
data class UserItemDataDto(
    val played: Boolean? = null,
    val isFavorite: Boolean? = null,
    val playbackPositionTicks: Long? = null,
    val playedPercentage: Double? = null,
    val unplayedItemCount: Int? = null,
)

@Serializable
data class ImageBlurHashes(
    val primary: Map<String, String>? = null,
    val backdrop: Map<String, String>? = null,
    val logo: Map<String, String>? = null,
    val thumb: Map<String, String>? = null,
)

@Serializable
data class ChapterInfo(val startPositionTicks: Long? = null, val name: String? = null, val imageTag: String? = null)

@Serializable
data class TrickplayInfoDto(
    val width: Int? = null,
    val height: Int? = null,
    val tileWidth: Int? = null,
    val tileHeight: Int? = null,
    val thumbnailCount: Int? = null,
    val interval: Int? = null,
)

@Serializable
data class MediaStream(
    val type: String? = null,
    val index: Int? = null,
    val codec: String? = null,
    val language: String? = null,
    val displayTitle: String? = null,
    val title: String? = null,
    val channels: Int? = null,
    val isDefault: Boolean? = null,
    val isForced: Boolean? = null,
    val isExternal: Boolean? = null,
    val isTextSubtitleStream: Boolean? = null,
    val deliveryUrl: String? = null,
    val deliveryMethod: String? = null,
    val width: Int? = null,
    val height: Int? = null,
    val bitDepth: Int? = null,
    val bitRate: Long? = null,
    val videoRange: String? = null,
    val videoRangeType: String? = null,
    val colorTransfer: String? = null,
    val pixelFormat: String? = null,
    val profile: String? = null,
    val audioSpatialFormat: String? = null,
    val dvProfile: Int? = null,
    val dvBlSignalCompatibilityId: Int? = null,
    val realFrameRate: Double? = null,
)

@Serializable
data class MediaSourceInfo(
    val id: String? = null,
    val container: String? = null,
    val bitrate: Long? = null,
    val runTimeTicks: Long? = null,
    val supportsDirectPlay: Boolean? = null,
    val supportsDirectStream: Boolean? = null,
    val transcodingUrl: String? = null,
    val eTag: String? = null,
    val defaultAudioStreamIndex: Int? = null,
    val defaultSubtitleStreamIndex: Int? = null,
    val mediaStreams: List<MediaStream>? = null,
)

@Serializable
data class BaseItemDto(
    val id: String = "",
    val name: String? = null,
    val type: String? = null,
    val originalTitle: String? = null,
    val overview: String? = null,
    val taglines: List<String>? = null,
    val productionYear: Int? = null,
    val premiereDate: String? = null,
    val endDate: String? = null,
    val status: String? = null,
    val runTimeTicks: Long? = null,
    val cumulativeRunTimeTicks: Long? = null,
    val communityRating: Float? = null,
    val criticRating: Float? = null,
    val officialRating: String? = null,
    val genreItems: List<NameGuidPair>? = null,
    val studios: List<NameGuidPair>? = null,
    val people: List<BaseItemPerson>? = null,
    val remoteTrailers: List<MediaUrl>? = null,
    val localTrailerCount: Int? = null,
    val userData: UserItemDataDto? = null,
    val seriesId: String? = null,
    val seriesName: String? = null,
    val seasonId: String? = null,
    val seasonName: String? = null,
    val indexNumber: Int? = null,
    val parentIndexNumber: Int? = null,
    val childCount: Int? = null,
    val recursiveItemCount: Int? = null,
    val collectionType: String? = null,
    val mediaSources: List<MediaSourceInfo>? = null,
    val mediaStreams: List<MediaStream>? = null,
    val imageTags: Map<String, String>? = null,
    val backdropImageTags: List<String>? = null,
    val parentBackdropItemId: String? = null,
    val parentBackdropImageTags: List<String>? = null,
    val parentLogoItemId: String? = null,
    val parentLogoImageTag: String? = null,
    val parentThumbItemId: String? = null,
    val parentThumbImageTag: String? = null,
    val seriesThumbImageTag: String? = null,
    val seriesPrimaryImageTag: String? = null,
    val imageBlurHashes: ImageBlurHashes? = null,
    val primaryImageAspectRatio: Double? = null,
    val isFolder: Boolean? = null,
    val chapters: List<ChapterInfo>? = null,
    val trickplay: Map<String, Map<String, TrickplayInfoDto>>? = null,
)

@Serializable
data class BaseItemDtoQueryResult(val items: List<BaseItemDto>? = null, val totalRecordCount: Int? = null)

@Serializable
data class QueryFilters(val genres: List<NameGuidPair>? = null)

@Serializable
data class QueryFiltersLegacy(val years: List<Int>? = null)

@Serializable
data class PlaybackInfoResponse(val mediaSources: List<MediaSourceInfo>? = null, val playSessionId: String? = null, val errorCode: String? = null)

@Serializable
data class MediaSegmentDto(val type: String? = null, val startTicks: Long? = null, val endTicks: Long? = null)

@Serializable
data class MediaSegmentDtoQueryResult(val items: List<MediaSegmentDto>? = null)

/** Rapport de lecture (début, progression, fin). */
@Serializable
data class PlaybackReportDto(
    val itemId: String,
    val mediaSourceId: String? = null,
    val playSessionId: String? = null,
    val positionTicks: Long,
    val isPaused: Boolean? = null,
    val isMuted: Boolean? = null,
    val canSeek: Boolean? = null,
    val playMethod: String? = null,
    val audioStreamIndex: Int? = null,
    val subtitleStreamIndex: Int? = null,
    val failed: Boolean? = null,
)

@Serializable
data class AuthenticateUserByName(val username: String, val pw: String)

@Serializable
data class QuickConnectDto(val secret: String)

@Serializable
data class DiscoveryResponse(val id: String? = null, val address: String? = null, val name: String? = null)

@Serializable
data class RemoteSubtitleInfo(
    val id: String? = null,
    val name: String? = null,
    val providerName: String? = null,
    val format: String? = null,
    val downloadCount: Int? = null,
    val communityRating: Double? = null,
    val isHashMatch: Boolean? = null,
    val hearingImpaired: Boolean? = null,
    val forced: Boolean? = null,
)
