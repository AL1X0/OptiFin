package app.optifin.tv.core.playback

import android.content.Context
import android.hardware.display.DisplayManager
import android.media.MediaCodecInfo
import android.media.MediaCodecInfo.CodecProfileLevel
import android.media.MediaCodecList
import android.os.Build
import android.view.Display

/**
 * Ce que le lecteur natif (Media3 + FFmpeg) lit sur ce téléviseur : décodeurs vidéo matériels,
 * gammes HDR affichées par l'écran, profils Dolby Vision. L'audio est toujours décodable
 * (extension FFmpeg : Dolby, DTS, TrueHD…), et transmis tel quel à l'ampli quand il le gère.
 */
data class DeviceCapabilities(
    val model: String = "Android TV",
    val osVersion: String = "",
    val videoCodecs: Set<String> = setOf("h264"),
    val hevcMain10: Boolean = false,
    val ranges: Set<DynamicRange> = setOf(DynamicRange.Sdr),
    val dolbyVisionProfiles: Set<Int> = emptySet(),
    val audioCodecs: Set<String> = FFMPEG_AUDIO,
    val containers: Set<String> = EXO_CONTAINERS,
    val maxWidth: Int = 1920,
) {
    val supportsDolbyVision: Boolean get() = dolbyVisionProfiles.isNotEmpty()

    val summary: String
        get() = "$model · $osVersion · vidéo ${videoCodecs.joinToString("/")}${if (hevcMain10) " (HEVC 10 bits)" else ""} · " +
            "gammes ${ranges.joinToString("/") { it.label }}" +
            (if (supportsDolbyVision) " · DV p${dolbyVisionProfiles.sorted().joinToString("/")}" else "") + " · max ${maxWidth}px"

    companion object {
        /** Audio lu par Media3 + extension FFmpeg de Jellyfin. */
        val FFMPEG_AUDIO = setOf("aac", "mp3", "mp2", "ac3", "eac3", "truehd", "dts", "flac", "alac", "opus", "vorbis", "pcm")

        /** Conteneurs que Media3 sait démuxer. */
        val EXO_CONTAINERS = setOf("mkv", "webm", "mp4", "m4v", "mov", "3gp", "ts", "mpegts", "m2ts", "mts", "avi", "flv", "ogg", "ogv", "mpg", "mpeg", "vob")

        fun probe(context: Context): DeviceCapabilities {
            val decoders = MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos.filter { !it.isEncoder }
            fun decodersFor(mime: String) = decoders.filter { info -> info.supportedTypes.any { it.equals(mime, true) } }
            fun hardware(mime: String) = decodersFor(mime).filter(::isHardware)

            val hevc = hardware("video/hevc")
            val video = mutableSetOf("h264")
            if (hevc.isNotEmpty()) video += "hevc"
            if (hardware("video/x-vnd.on2.vp9").isNotEmpty()) video += "vp9"
            if (hardware("video/av01").isNotEmpty()) video += "av1"
            if (hardware("video/mpeg2").isNotEmpty()) video += "mpeg2video"
            if (decodersFor("video/x-vnd.on2.vp8").isNotEmpty()) video += "vp8"
            if (decodersFor("video/mp4v-es").isNotEmpty()) video += "mpeg4"

            val hevcMain10 = hevc.any { info ->
                info.getCapabilitiesForType("video/hevc").profileLevels.any {
                    it.profile == CodecProfileLevel.HEVCProfileMain10 || it.profile == CodecProfileLevel.HEVCProfileMain10HDR10
                }
            }
            val uhd = (hevc + hardware("video/avc")).any { info ->
                val type = info.supportedTypes.first { it.startsWith("video/") }
                val caps = info.getCapabilitiesForType(type).videoCapabilities
                caps != null && caps.supportedWidths.upper >= 3840
            }

            // Gammes HDR : seulement celles que l'écran affiche (Media3 ne convertit pas le HDR en SDR).
            val hdrTypes = displayHdrTypes(context)
            val ranges = mutableSetOf(DynamicRange.Sdr)
            if (hevcMain10 && Display.HdrCapabilities.HDR_TYPE_HDR10 in hdrTypes) ranges += DynamicRange.Hdr10
            if (hevcMain10 && Display.HdrCapabilities.HDR_TYPE_HLG in hdrTypes) ranges += DynamicRange.Hlg
            if (Build.VERSION.SDK_INT >= 29 && Display.HdrCapabilities.HDR_TYPE_HDR10_PLUS in hdrTypes) ranges += DynamicRange.Hdr10Plus

            val dvProfiles = mutableSetOf<Int>()
            if (Display.HdrCapabilities.HDR_TYPE_DOLBY_VISION in hdrTypes) {
                decodersFor("video/dolby-vision").forEach { info ->
                    info.getCapabilitiesForType("video/dolby-vision").profileLevels.forEach { level ->
                        dolbyVisionProfile(level.profile)?.let(dvProfiles::add)
                    }
                }
                // Profil 7 (double couche des Blu-ray UHD) : annoncé par bien des box, mais seul le
                // Shield le décode vraiment ; ailleurs, la couche de base HDR10 est lue.
                if (!Build.MODEL.contains("SHIELD", ignoreCase = true)) dvProfiles.remove(7)
            }
            if (dvProfiles.isNotEmpty()) ranges += DynamicRange.DolbyVision

            return DeviceCapabilities(
                model = "${Build.MANUFACTURER} ${Build.MODEL}",
                osVersion = "Android ${Build.VERSION.RELEASE}",
                videoCodecs = video,
                hevcMain10 = hevcMain10,
                ranges = ranges,
                dolbyVisionProfiles = dvProfiles,
                maxWidth = if (uhd) 3840 else 1920,
            )
        }

        private fun isHardware(info: MediaCodecInfo): Boolean =
            if (Build.VERSION.SDK_INT >= 29) info.isHardwareAccelerated
            else info.name.lowercase().let { !it.startsWith("omx.google.") && !it.startsWith("c2.android.") }

        @Suppress("DEPRECATION")
        private fun displayHdrTypes(context: Context): Set<Int> {
            val display = (context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager).getDisplay(Display.DEFAULT_DISPLAY)
                ?: return emptySet()
            return display.hdrCapabilities?.supportedHdrTypes?.toSet() ?: emptySet()
        }

        private fun dolbyVisionProfile(profile: Int): Int? = when (profile) {
            CodecProfileLevel.DolbyVisionProfileDvheDtr -> 4
            CodecProfileLevel.DolbyVisionProfileDvheStn -> 5
            CodecProfileLevel.DolbyVisionProfileDvheDth -> 7
            CodecProfileLevel.DolbyVisionProfileDvheSt -> 8
            CodecProfileLevel.DolbyVisionProfileDvavSe -> 9
            else -> if (Build.VERSION.SDK_INT >= 30 && profile == CodecProfileLevel.DolbyVisionProfileDvav110) 10 else null
        }
    }
}
