package app.optifin.tv.core.playback

import app.optifin.tv.core.api.MediaSourceInfo
import app.optifin.tv.core.api.MediaStream

enum class DynamicRange(val label: String) {
    Sdr("SDR"), Hdr10("HDR10"), Hdr10Plus("HDR10+"), Hlg("HLG"), DolbyVision("Dolby Vision")
}

data class VideoInfo(
    val codec: String,
    val profile: String? = null,
    val bitDepth: Int? = null,
    val width: Int? = null,
    val height: Int? = null,
    val range: DynamicRange = DynamicRange.Sdr,
    /** Profil Dolby Vision (5, 7, 8…), null sans DV. */
    val dvProfile: Int? = null,
    /** Couche de base exploitable sans décodeur DV (HDR10, HLG, SDR) ; null = aucune (profil 5). */
    val dvBaseLayer: DynamicRange? = null,
) {
    val isDolbyVision: Boolean get() = range == DynamicRange.DolbyVision
    val isHdr: Boolean get() = range != DynamicRange.Sdr
    val is10Bit: Boolean get() = (bitDepth ?: 8) > 8
    val isUhd: Boolean get() = (width ?: 0) > 1920 || (height ?: 0) > 1088

    val summary: String
        get() = listOfNotNull(
            codec.uppercase(),
            if (width != null && height != null) "$width×$height" else null,
            bitDepth?.let { "$it bits" },
            if (isDolbyVision) "DV p${dvProfile ?: "?"}${dvBaseLayer?.let { " (BL ${it.label})" } ?: ""}" else range.label,
        ).joinToString(" · ")
}

data class AudioInfo(val index: Int, val codec: String, val profile: String? = null, val channels: Int? = null, val atmos: Boolean = false)

data class SubtitleInfo(val index: Int, val codec: String, val isText: Boolean = true, val isExternal: Boolean = false) {
    val isAss: Boolean get() = codec == "ass" || codec == "ssa"
    val isBitmap: Boolean get() = !isText
}

/** Description technique d'une source, telle que l'analyse l'[EngineSelector]. */
data class SourceProfile(
    val container: String,
    val bitrate: Long? = null,
    val video: VideoInfo? = null,
    val audio: List<AudioInfo> = emptyList(),
    val subtitles: List<SubtitleInfo> = emptyList(),
) {
    val containers: Set<String> get() = container.lowercase().split(',').map { it.trim() }.filter { it.isNotEmpty() }.toSet()

    fun audioAt(index: Int?): AudioInfo? =
        if (index == null) audio.firstOrNull() else audio.firstOrNull { it.index == index } ?: audio.firstOrNull()

    fun subtitleAt(index: Int?): SubtitleInfo? = if (index == null || index < 0) null else subtitles.firstOrNull { it.index == index }

    companion object {
        /** MediaSourceInfo de Jellyfin → profil. */
        fun from(source: MediaSourceInfo): SourceProfile {
            val streams = source.mediaStreams.orEmpty().sortedBy { it.index ?: 0 }
            val video = streams.firstOrNull { it.type == "Video" }
            return SourceProfile(
                container = source.container ?: "",
                bitrate = source.bitrate,
                video = video?.let(::videoOf),
                audio = streams.filter { it.type == "Audio" && it.index != null }.map { s ->
                    AudioInfo(s.index!!, normalizeCodec(s.codec), audioProfile(s), s.channels,
                        s.audioSpatialFormat == "DolbyAtmos" || s.profile?.lowercase()?.contains("atmos") == true)
                },
                subtitles = streams.filter { it.type == "Subtitle" && it.index != null }.map { s ->
                    val codec = normalizeCodec(s.codec)
                    SubtitleInfo(s.index!!, codec, s.isTextSubtitleStream ?: isTextCodec(codec), s.isExternal ?: false)
                },
            )
        }

        private fun videoOf(s: MediaStream): VideoInfo {
            val (range, base) = rangeOf(s)
            return VideoInfo(
                codec = normalizeCodec(s.codec),
                profile = s.profile,
                bitDepth = s.bitDepth ?: if (s.pixelFormat?.contains("10") == true) 10 else null,
                width = s.width,
                height = s.height,
                range = range,
                dvProfile = if (range == DynamicRange.DolbyVision) s.dvProfile else null,
                dvBaseLayer = base,
            )
        }

        /** Gamme dynamique et, pour le Dolby Vision, la couche de base exploitable sans DV. */
        private fun rangeOf(s: MediaStream): Pair<DynamicRange, DynamicRange?> {
            val dv = DynamicRange.DolbyVision
            val fromCompat = when (s.dvBlSignalCompatibilityId) {
                1, 6 -> DynamicRange.Hdr10
                2 -> DynamicRange.Sdr
                4 -> DynamicRange.Hlg
                else -> null
            }
            return when (s.videoRangeType) {
                "SDR" -> DynamicRange.Sdr to null
                "HDR10" -> DynamicRange.Hdr10 to null
                "HDR10Plus" -> DynamicRange.Hdr10Plus to null
                "HLG" -> DynamicRange.Hlg to null
                "DOVI" -> dv to (if (s.dvProfile == 5) null else fromCompat)
                "DOVIWithHDR10", "DOVIWithHDR10Plus", "DOVIWithEL", "DOVIWithELHDR10Plus" -> dv to (fromCompat ?: DynamicRange.Hdr10)
                "DOVIWithHLG" -> dv to DynamicRange.Hlg
                "DOVIWithSDR" -> dv to DynamicRange.Sdr
                "DOVIInvalid" -> DynamicRange.Hdr10 to null
                else -> when (s.colorTransfer?.lowercase()) {
                    "smpte2084" -> DynamicRange.Hdr10
                    "arib-std-b67" -> DynamicRange.Hlg
                    else -> if (s.videoRange == "HDR") DynamicRange.Hdr10 else DynamicRange.Sdr
                } to null
            }
        }

        private fun audioProfile(s: MediaStream): String? {
            val codec = normalizeCodec(s.codec)
            val profile = s.profile
            if (codec == "dts" && !profile.isNullOrEmpty()) return profile
            if (codec == "truehd") return if (profile?.lowercase()?.contains("atmos") == true) "TrueHD Atmos" else "TrueHD"
            return null
        }

        private fun isTextCodec(codec: String) = codec in setOf("srt", "ass", "ssa", "vtt", "ttml", "mov_text", "sub", "smi")
    }
}

/** Normalise les noms de codecs de Jellyfin/ffmpeg. */
fun normalizeCodec(codec: String?): String {
    val c = (codec ?: "").lowercase().trim()
    return when {
        c in setOf("avc", "avc1", "h.264") -> "h264"
        c in setOf("h265", "hvc1", "hev1", "h.265", "dvhe", "dvh1") -> "hevc"
        c == "av01" -> "av1"
        c in setOf("mlp", "truehd") -> "truehd"
        c in setOf("dca", "dts", "dts-hd", "dtshd") -> "dts"
        c in setOf("ec3", "eac3", "e-ac-3") -> "eac3"
        c in setOf("ac-3", "ac3") -> "ac3"
        c == "subrip" -> "srt"
        c == "webvtt" -> "vtt"
        c in setOf("pgs", "hdmv_pgs_subtitle") -> "pgssub"
        c == "dvd_subtitle" -> "dvdsub"
        c == "dvb_subtitle" -> "dvbsub"
        c.startsWith("pcm") -> "pcm"
        else -> c
    }
}
