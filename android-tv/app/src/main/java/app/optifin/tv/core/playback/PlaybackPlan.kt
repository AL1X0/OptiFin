package app.optifin.tv.core.playback

import app.optifin.tv.core.api.RemoteSubtitleInfo
import app.optifin.tv.core.media.MediaItem

enum class PlayMethod(val apiName: String, val label: String) {
    DirectPlay("DirectPlay", "Lecture directe"),
    DirectStream("DirectStream", "Remux"),
    Transcode("Transcode", "Transcodage"),
}

enum class TrackType { Audio, Subtitle }

/** Piste audio ou de sous-titres d'une source. */
data class MediaTrack(
    val index: Int,
    val type: TrackType,
    val label: String,
    val language: String? = null,
    val codec: String? = null,
    val isDefault: Boolean = false,
    val isForced: Boolean = false,
    val isExternal: Boolean = false,
    val isTextBased: Boolean = true,
    val deliveryUrl: String? = null,
    val deliveryMethod: String? = null,
    val channels: Int? = null,
)

/** Comment lire un élément : URL du flux, pistes, mode choisi par le serveur. */
data class PlaybackPlan(
    val itemId: String,
    val mediaSourceId: String,
    val playSessionId: String?,
    val method: PlayMethod,
    val streamUrl: String,
    val audioTracks: List<MediaTrack> = emptyList(),
    val subtitleTracks: List<MediaTrack> = emptyList(),
    val audioIndex: Int? = null,
    val subtitleIndex: Int? = null,
    val container: String? = null,
    val bitrate: Long? = null,
    val videoCodec: String? = null,
    val videoRangeType: String? = null,
    val startMs: Long = 0,
    val runtimeMs: Long? = null,
    val source: SourceProfile,
) {
    val currentAudio: MediaTrack? get() = audioTracks.firstOrNull { it.index == audioIndex }
    val currentSubtitle: MediaTrack? get() = subtitleTracks.firstOrNull { it.index == subtitleIndex }

    /** Pistes intégrées au flux livré (pas les fichiers à côté ni les pistes servies à part). */
    fun embedded(type: TrackType): List<MediaTrack> =
        (if (type == TrackType.Audio) audioTracks else subtitleTracks)
            .filter { !it.isExternal && it.deliveryMethod != "External" && it.deliveryMethod != "Hls" }
            .sortedBy { it.index }

    /** Rang (0, 1, …) d'une piste intégrée parmi celles de son type ; null si externe. */
    fun embeddedOrdinal(track: MediaTrack): Int? = embedded(track.type).indexOfFirst { it.index == track.index }.takeIf { it >= 0 }
}

enum class SegmentType(val skipLabel: String) {
    Intro("Passer l’intro"),
    Recap("Passer le récapitulatif"),
    Preview("Passer l’aperçu"),
    Commercial("Passer la publicité"),
    Outro("Passer le générique"),
}

data class MediaSegment(val type: SegmentType, val startMs: Long, val endMs: Long) {
    /** Trop court pour mériter un bouton (moins de 3 s). */
    val isSkippable: Boolean get() = endMs - startMs >= 3000
    fun contains(position: Long) = position in startMs until endMs
}

data class Chapter(val index: Int, val startMs: Long, val name: String, val imageTag: String?)

/** Vignettes de la barre de progression (planches d'images du serveur). */
data class Trickplay(val width: Int, val height: Int, val tileWidth: Int, val tileHeight: Int, val count: Int, val intervalMs: Int) {
    val perTile: Int get() = tileWidth * tileHeight
}

/** Compléments d'une lecture (facultatifs : absents du serveur → vides). */
data class PlaybackExtras(
    val chapters: List<Chapter> = emptyList(),
    val segments: List<MediaSegment> = emptyList(),
    val nextEpisode: MediaItem? = null,
    val trickplay: Trickplay? = null,
) {
    fun chapterAt(position: Long): Chapter? = chapters.lastOrNull { it.startMs <= position }

    /** Segment à proposer de passer (pas le générique quand un épisode suivant existe). */
    fun skippableAt(position: Long): MediaSegment? = segments.firstOrNull { s ->
        s.isSkippable && s.contains(position) && s.endMs - position >= 1000 && !(s.type == SegmentType.Outro && nextEpisode != null)
    }

    /** Moment de proposer l'épisode suivant : début du générique, sinon 30 s avant la fin (jamais avant la moitié). */
    fun upNextAt(duration: Long): Long? {
        if (nextEpisode == null || duration <= 0) return null
        val outro = segments.firstOrNull { it.type == SegmentType.Outro && it.endMs >= duration * 0.8 }
        val at = outro?.startMs ?: (duration - 30_000)
        return maxOf(at, duration / 2)
    }

    companion object {
        val Empty = PlaybackExtras()
    }
}

/** Sous-titre trouvé en ligne par un fournisseur du serveur (OpenSubtitles…). */
data class RemoteSubtitle(
    val id: String,
    val name: String,
    val provider: String?,
    val format: String?,
    val downloads: Int?,
    val hashMatch: Boolean,
    val hearingImpaired: Boolean,
    val forced: Boolean,
) {
    val details: String
        get() = listOfNotNull(
            provider, format?.uppercase(), downloads?.takeIf { it > 0 }?.let { "$it téléchargements" },
            if (hashMatch) "correspond au fichier" else null, if (hearingImpaired) "malentendants" else null,
            if (forced) "forcés" else null,
        ).joinToString(" · ")

    companion object {
        fun from(list: List<RemoteSubtitleInfo>): List<RemoteSubtitle> = list
            .filter { !it.id.isNullOrEmpty() }
            .map {
                RemoteSubtitle(it.id!!, it.name?.trim()?.ifEmpty { null } ?: "Sous-titre ${it.id}", it.providerName, it.format,
                    it.downloadCount, it.isHashMatch == true, it.hearingImpaired == true, it.forced == true)
            }
            .sortedWith(compareByDescending<RemoteSubtitle> { it.hashMatch }.thenByDescending { it.downloads ?: 0 })
    }
}
