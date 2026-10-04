package app.optifin.optifin_native_player

import android.content.Context
import android.hardware.display.DisplayManager
import android.media.MediaCodecInfo
import android.media.MediaCodecInfo.CodecProfileLevel
import android.media.MediaCodecList
import android.os.Build
import android.view.Display

/**
 * Ce que Media3 peut lire sur cet appareil : décodeurs matériels (MediaCodec),
 * gammes HDR de l'écran, profils Dolby Vision. Clés lues par
 * `DeviceCapabilities.fromJson` côté Dart.
 */
object CapabilitiesProbe {
    fun probe(context: Context): Map<String, Any?> {
        val decoders = MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos.filter { !it.isEncoder }

        fun decodersFor(mime: String) = decoders.filter { info -> info.supportedTypes.any { it.equals(mime, true) } }
        fun hardware(mime: String) = decodersFor(mime).filter(::isHardware)
        fun any(mime: String) = decodersFor(mime).isNotEmpty()

        val hevc = hardware("video/hevc")
        val video = mutableListOf("h264")
        if (hevc.isNotEmpty()) video.add("hevc")
        if (hardware("video/x-vnd.on2.vp9").isNotEmpty()) video.add("vp9")
        if (hardware("video/av01").isNotEmpty()) video.add("av1")

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
        val ranges = mutableListOf("sdr")
        if (hevcMain10 && Display.HdrCapabilities.HDR_TYPE_HDR10 in hdrTypes) ranges.add("hdr10")
        if (hevcMain10 && Display.HdrCapabilities.HDR_TYPE_HLG in hdrTypes) ranges.add("hlg")
        if (Build.VERSION.SDK_INT >= 29 && Display.HdrCapabilities.HDR_TYPE_HDR10_PLUS in hdrTypes) ranges.add("hdr10Plus")

        val dvProfiles = mutableSetOf<Int>()
        if (Display.HdrCapabilities.HDR_TYPE_DOLBY_VISION in hdrTypes) {
            decodersFor("video/dolby-vision").forEach { info ->
                info.getCapabilitiesForType("video/dolby-vision").profileLevels.forEach { level ->
                    dolbyVisionProfile(level.profile)?.let(dvProfiles::add)
                    // Profil 7 (double couche des Blu-ray UHD) : annoncé par bien des box, mais seul
                    // le Shield le décode vraiment ; ailleurs, la couche de base HDR10 est lue.
                    if (!Build.MODEL.contains("SHIELD", ignoreCase = true)) dvProfiles.remove(7)
                }
            }
        }
        if (dvProfiles.isNotEmpty()) ranges.add("dolbyVision")

        val audio = mutableListOf("aac", "mp3")
        mapOf(
            "ac3" to "audio/ac3",
            "eac3" to "audio/eac3",
            "truehd" to "audio/true-hd",
            "dts" to "audio/vnd.dts",
            "flac" to "audio/flac",
            "opus" to "audio/opus",
            "vorbis" to "audio/vorbis",
        ).forEach { (codec, mime) -> if (any(mime)) audio.add(codec) }

        return mapOf(
            "platform" to "android",
            "nativeAvailable" to true,
            "model" to "${Build.MANUFACTURER} ${Build.MODEL}",
            "osVersion" to "Android ${Build.VERSION.RELEASE}",
            "videoCodecs" to video,
            "hevcMain10" to hevcMain10,
            "ranges" to ranges,
            "dolbyVisionProfiles" to dvProfiles.sorted(),
            "audioCodecs" to audio,
            "containers" to listOf("mp4", "m4v", "mov", "mkv", "webm", "ts", "mpegts"),
            "maxWidth" to if (uhd) 3840 else 1920,
        )
    }

    private fun isHardware(info: MediaCodecInfo): Boolean =
        if (Build.VERSION.SDK_INT >= 29) {
            info.isHardwareAccelerated
        } else {
            val name = info.name.lowercase()
            !name.startsWith("omx.google.") && !name.startsWith("c2.android.")
        }

    @Suppress("DEPRECATION")
    private fun displayHdrTypes(context: Context): Set<Int> {
        val manager = context.getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager ?: return emptySet()
        val display = manager.getDisplay(Display.DEFAULT_DISPLAY) ?: return emptySet()
        return display.hdrCapabilities?.supportedHdrTypes?.toSet() ?: emptySet()
    }

    private fun dolbyVisionProfile(profile: Int): Int? = when (profile) {
        CodecProfileLevel.DolbyVisionProfileDvheStn -> 5
        CodecProfileLevel.DolbyVisionProfileDvheDtb -> 7
        CodecProfileLevel.DolbyVisionProfileDvheSt -> 8
        CodecProfileLevel.DolbyVisionProfileDvavSe -> 9
        else -> null
    }
}
