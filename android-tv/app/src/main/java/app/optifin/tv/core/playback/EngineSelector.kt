package app.optifin.tv.core.playback

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Choix du moteur et du mode de livraison, avant chaque lecture (pur, testé).
 *
 * Sur téléviseur, le lecteur natif (Media3 + FFmpeg) lit l'audio de tous les formats et les
 * sous-titres intégrés (SRT, ASS simplifiés, PGS, VobSub) : il est le moteur par défaut.
 * 1. **Transcodage** si le débit source dépasse la limite (ou s'il est demandé).
 * 2. Préférence explicite (Natif / mpv) si possible.
 * 3. Vidéo lisible par le natif (codec, 10 bits, résolution, HDR / Dolby Vision affichable) :
 *    lecture directe si le conteneur passe, sinon **remux** serveur (vidéo copiée).
 *    Exception : sous-titres image + remux (le remux perd les pistes image) → mpv en direct.
 * 4. Sinon **mpv** en lecture directe (décodage logiciel jusqu'en 1080p).
 * 5. Transcodage serveur en dernier recours.
 * Chaque décision a ses replis (bascule automatique) : l'autre moteur, puis le transcodage.
 */
enum class EngineKind(val label: String) { Native("Natif"), Mpv("mpv") }

enum class Delivery(val label: String) { DirectPlay("Lecture directe"), Remux("Remux"), Transcode("Transcodage") }

/** Affichage du sous-titre choisi. */
enum class SubtitleRoute { None, Engine, BurnIn }

enum class EnginePreference(val label: String) { Auto("Automatique"), Native("Lecteur natif"), Mpv("mpv") }

/** Sous-titres image (PGS, VobSub) quand ils ne peuvent pas rester dans le flux. */
enum class ImageSubtitlePolicy(val label: String) { Auto("Automatique (mpv)"), BurnIn("Incruster (serveur)") }

data class EngineDecision(
    val engine: EngineKind,
    val delivery: Delivery,
    val subtitles: SubtitleRoute = SubtitleRoute.None,
    val reencodeVideo: Boolean = false,
    val reason: String,
) {
    val isNative: Boolean get() = engine == EngineKind.Native
    val label: String get() = "${engine.label} · ${delivery.label}"
    fun sameRoute(other: EngineDecision) = engine == other.engine && delivery == other.delivery && subtitles == other.subtitles
}

data class EngineSelection(val primary: EngineDecision, val fallbacks: List<EngineDecision> = emptyList(), val trace: List<String> = emptyList()) {
    val chain: List<EngineDecision> get() = listOf(primary) + fallbacks
}

data class SelectionRequest(
    val source: SourceProfile,
    val device: DeviceCapabilities,
    val audioIndex: Int? = null,
    val subtitleIndex: Int? = null,
    val maxBitrate: Long = 200_000_000,
    val preference: EnginePreference = EnginePreference.Auto,
    val imageSubtitles: ImageSubtitlePolicy = ImageSubtitlePolicy.Auto,
    val forceTranscode: Boolean = false,
)

object EngineSelector {
    fun select(r: SelectionRequest): EngineSelection = Analysis(r).select()
}

private class Analysis(val r: SelectionRequest) {
    val video = r.source.video
    val audio = r.source.audioAt(r.audioIndex)
    val subtitle = r.source.subtitleAt(r.subtitleIndex)
    val trace = mutableListOf<String>()
    val device get() = r.device

    val nativeVideoProblem: String?
        get() {
            val v = video ?: return null
            if (v.codec !in device.videoCodecs) return "codec vidéo ${v.codec.uppercase()} non pris en charge"
            if (v.codec == "hevc" && v.is10Bit && !device.hevcMain10) return "HEVC 10 bits non pris en charge"
            if ((v.width ?: 0) > device.maxWidth) return "résolution ${v.width} px > ${device.maxWidth} px"
            if (v.isDolbyVision) {
                if (v.dvProfile in device.dolbyVisionProfiles) return null
                val bl = v.dvBaseLayer
                if (bl != null && (bl == DynamicRange.Sdr || bl in device.ranges)) return null
                return "Dolby Vision profil ${v.dvProfile ?: "?"} sans couche de base compatible"
            }
            if (v.isHdr && !rangeSupported(v.range)) return "${v.range.label} non affichable"
            return null
        }

    fun rangeSupported(range: DynamicRange) =
        range in device.ranges || (range == DynamicRange.Hdr10Plus && DynamicRange.Hdr10 in device.ranges)

    val mpvVideoProblem: String?
        get() {
            val v = video ?: return null
            if (v.isDolbyVision && v.dvBaseLayer == null) return "Dolby Vision profil ${v.dvProfile ?: "?"} : couleurs faussées hors lecteur Dolby Vision"
            val hardware = v.codec in device.videoCodecs && !(v.codec == "hevc" && v.is10Bit && !device.hevcMain10)
            if (hardware && (v.width ?: 0) <= device.maxWidth) return null
            if (v.isUhd) return "${v.codec.uppercase()} ${v.width} px sans décodage matériel"
            return null
        }

    val nativeAudioProblem: String? get() = audio?.takeIf { it.codec !in device.audioCodecs }?.let { "audio ${it.profile ?: it.codec.uppercase()}" }

    val nativeContainerProblem: String?
        get() {
            val containers = r.source.containers
            if (containers.isEmpty() || containers.any { it in device.containers }) return null
            return "conteneur ${containers.first().uppercase()}"
        }

    val imageSubtitle get() = subtitle?.isBitmap == true

    fun subtitlesFor(engine: EngineKind, delivery: Delivery): SubtitleRoute {
        val s = subtitle ?: return SubtitleRoute.None
        // Remux / transcodage : les sous-titres image ne passent que s'ils sont incrustés.
        if (s.isBitmap && !s.isExternal && delivery != Delivery.DirectPlay) return SubtitleRoute.BurnIn
        return SubtitleRoute.Engine
    }

    fun decision(engine: EngineKind, delivery: Delivery, reason: String, reencode: Boolean = false): EngineDecision {
        val route = subtitlesFor(engine, delivery)
        val burnIn = route == SubtitleRoute.BurnIn
        return EngineDecision(engine, if (burnIn) Delivery.Transcode else delivery, route, reencode || burnIn, reason)
    }

    val nativeDelivery: Delivery get() = if (nativeContainerProblem == null && nativeAudioProblem == null) Delivery.DirectPlay else Delivery.Remux

    fun native(reason: String): EngineDecision {
        val delivery = nativeDelivery
        val why = listOfNotNull(nativeContainerProblem, nativeAudioProblem?.let { "$it converti" })
        return decision(EngineKind.Native, delivery, if (delivery == Delivery.Remux && why.isNotEmpty()) "$reason (remux : ${why.joinToString(", ")})" else reason)
    }

    fun select(): EngineSelection {
        traceAnalysis()
        val primary = primary()
        trace += "→ ${primary.label} : ${primary.reason}"
        return EngineSelection(primary, fallbacks(primary), trace)
    }

    fun traceAnalysis() {
        trace += "Source : ${r.source.container}${r.source.bitrate?.let { ", ${mbps(it)}" } ?: ""}"
        video?.let { trace += "Vidéo : ${it.summary}" }
        audio?.let { trace += "Audio : ${it.profile ?: it.codec.uppercase()}${it.channels?.let { c -> " $c can." } ?: ""}${if (it.atmos) " Atmos" else ""}" }
        subtitle?.let { trace += "Sous-titres : ${it.codec.uppercase()}${if (it.isBitmap) " (image)" else ""}" }
        fun ok(problem: String?) = problem?.let { "non ($it)" } ?: "oui"
        trace += "Natif — vidéo : ${ok(nativeVideoProblem)}, audio : ${ok(nativeAudioProblem)}, conteneur : ${ok(nativeContainerProblem)}"
        trace += "mpv — vidéo : ${ok(mpvVideoProblem)}"
    }

    fun primary(): EngineDecision {
        val nativeVideo = nativeVideoProblem
        val mpvVideo = mpvVideoProblem
        val bitrate = r.source.bitrate

        if (r.forceTranscode || (bitrate != null && bitrate > r.maxBitrate)) {
            val engine = if (r.preference == EnginePreference.Mpv) EngineKind.Mpv else EngineKind.Native
            return decision(engine, Delivery.Transcode,
                if (r.forceTranscode) "Transcodage demandé" else "Débit source ${mbps(bitrate!!)} supérieur à la limite (${mbps(r.maxBitrate)})")
        }
        if (r.preference == EnginePreference.Mpv) {
            return if (mpvVideo == null) decision(EngineKind.Mpv, Delivery.DirectPlay, "Moteur mpv choisi dans les réglages")
            else decision(EngineKind.Mpv, Delivery.Transcode, "mpv choisi, mais $mpvVideo : transcodage")
        }
        if (r.preference == EnginePreference.Native) {
            return if (nativeVideo == null) native("Lecteur natif choisi dans les réglages")
            else decision(EngineKind.Native, Delivery.Transcode, "Lecteur natif choisi, mais $nativeVideo : transcodage")
        }
        if (nativeVideo == null) {
            val kind = video?.let { v ->
                when {
                    v.isDolbyVision -> if (v.dvProfile in device.dolbyVisionProfiles) "Dolby Vision" else "Dolby Vision (couche de base ${v.dvBaseLayer?.label})"
                    v.isHdr -> v.range.label
                    else -> null
                }
            }
            // Le remux perd les sous-titres image : mpv les lit tels quels en lecture directe.
            if (nativeDelivery == Delivery.Remux && imageSubtitle && r.imageSubtitles == ImageSubtitlePolicy.Auto && mpvVideo == null) {
                return decision(EngineKind.Mpv, Delivery.DirectPlay, "Sous-titres image et ${nativeContainerProblem ?: "remux"} : mpv")
            }
            return native(if (kind != null) "$kind : lecteur natif" else "Lecture native")
        }
        if (mpvVideo == null) return decision(EngineKind.Mpv, Delivery.DirectPlay, "mpv : $nativeVideo")
        return decision(EngineKind.Native, Delivery.Transcode, "Aucun moteur ne lit ce fichier tel quel ($nativeVideo ; $mpvVideo) : transcodage", reencode = true)
    }

    fun fallbacks(primary: EngineDecision): List<EngineDecision> {
        val out = mutableListOf<EngineDecision>()
        fun add(d: EngineDecision) {
            if (primary.sameRoute(d) || out.any(d::sameRoute)) return
            out += d
        }
        val other = if (primary.isNative) EngineKind.Mpv else EngineKind.Native
        if (primary.delivery != Delivery.Transcode) {
            if (primary.isNative) {
                if (mpvVideoProblem == null) add(decision(EngineKind.Mpv, Delivery.DirectPlay, "Repli : mpv"))
            } else if (nativeVideoProblem == null) {
                add(native("Repli : lecteur natif"))
            }
            add(decision(other, Delivery.Transcode, "Repli : transcodage serveur"))
        } else {
            add(decision(other, Delivery.Transcode, "Repli : transcodage avec ${other.label}"))
        }
        return out
    }
}

private fun mbps(bps: Long) = if (bps >= 10_000_000) "${bps / 1_000_000} Mb/s" else "${"%.1f".format(bps / 1e6)} Mb/s"

/** Profils d'appareil envoyés au serveur dans PlaybackInfo (un par moteur). */
object DeviceProfiles {
    private val textSubtitles = listOf("srt", "subrip", "ass", "ssa", "vtt", "webvtt", "ttml", "sub", "smi")
    private val bitmapSubtitles = listOf("pgs", "pgssub", "dvdsub", "dvbsub", "vobsub", "xsub")

    private fun subtitleProfiles(embed: List<String>, external: List<String>) = buildJsonArray {
        for (f in embed) add(buildJsonObject { put("Format", f); put("Method", "Embed") })
        for (f in external) add(buildJsonObject { put("Format", f); put("Method", "External") })
        for (f in bitmapSubtitles) add(buildJsonObject { put("Format", f); put("Method", "Encode") })
    }

    private fun transcoding(container: String, video: String, audio: String, segment: Int?) = buildJsonArray {
        add(buildJsonObject {
            put("Type", "Video"); put("Container", container); put("Protocol", "hls"); put("Context", "Streaming")
            put("VideoCodec", video); put("AudioCodec", audio); put("MaxAudioChannels", "8"); put("MinSegments", 1)
            if (segment != null) put("SegmentLength", segment)
            put("BreakOnNonKeyFrames", true)
        })
        add(buildJsonObject { put("Type", "Audio"); put("Container", "mp3"); put("Protocol", "http"); put("Context", "Streaming"); put("AudioCodec", "mp3") })
    }

    /** libmpv : lecture directe de pratiquement tout. */
    fun mpv(maxBitrate: Long): JsonObject = buildJsonObject {
        put("Name", "OptiFin TV (mpv)")
        put("MaxStreamingBitrate", maxBitrate)
        put("MaxStaticBitrate", 400_000_000)
        put("MusicStreamingTranscodingBitrate", 320_000)
        put("DirectPlayProfiles", buildJsonArray {
            add(buildJsonObject { put("Type", "Video"); put("Container", "mkv,mp4,m4v,mov,webm,avi,ts,m2ts,mts,mpegts,wmv,asf,flv,3gp,ogv,ogm,vob,mpg,mpeg") })
            add(buildJsonObject { put("Type", "Audio"); put("Container", "mp3,aac,m4a,m4b,flac,alac,wav,ogg,oga,opus,wma,ape,wv,mka,webma") })
        })
        put("TranscodingProfiles", transcoding("ts", "hevc,h264", "aac,ac3,eac3,mp3,opus", null))
        put("ContainerProfiles", JsonArray(emptyList()))
        put("CodecProfiles", JsonArray(emptyList()))
        put("SubtitleProfiles", subtitleProfiles(textSubtitles + bitmapSubtitles, textSubtitles))
    }

    /** Media3 + FFmpeg, dérivé des capacités mesurées. */
    fun native(caps: DeviceCapabilities, maxBitrate: Long): JsonObject {
        val video = listOf("hevc", "h264", "av1", "vp9", "vp8", "mpeg2video", "mpeg4").filter { it == "h264" || it in caps.videoCodecs }
        val audio = listOf("aac", "mp3", "mp2", "ac3", "eac3", "truehd", "dts", "flac", "alac", "opus", "vorbis", "pcm").filter { it in caps.audioCodecs }
        val hlsVideo = listOfNotNull(if ("hevc" in caps.videoCodecs) "hevc" else null, "h264")
        val ranges = nativeVideoRangeTypes(caps)
        return buildJsonObject {
            put("Name", "OptiFin TV (Media3)")
            put("MaxStreamingBitrate", maxBitrate)
            put("MaxStaticBitrate", 400_000_000)
            put("MusicStreamingTranscodingBitrate", 320_000)
            put("DirectPlayProfiles", buildJsonArray {
                add(buildJsonObject {
                    put("Type", "Video"); put("Container", caps.containers.joinToString(","))
                    put("VideoCodec", video.joinToString(",")); put("AudioCodec", audio.joinToString(","))
                })
                add(buildJsonObject { put("Type", "Audio"); put("Container", "mp3,aac,m4a,m4b,flac,alac,wav,opus,ogg,mka") })
            })
            // HLS fMP4 : transporte HEVC, HDR10 et Dolby Vision ; vidéo copiée quand elle est compatible.
            put("TranscodingProfiles", transcoding("mp4", hlsVideo.joinToString(","), "aac,eac3,ac3,mp3,opus,flac", 3))
            put("ContainerProfiles", JsonArray(emptyList()))
            put("CodecProfiles", buildJsonArray {
                for (codec in listOf("hevc", "av1")) add(buildJsonObject {
                    put("Type", "Video"); put("Codec", codec)
                    put("Conditions", buildJsonArray {
                        add(buildJsonObject {
                            put("Condition", "EqualsAny"); put("Property", "VideoRangeType")
                            put("Value", ranges.joinToString("|")); put("IsRequired", false)
                        })
                        if (codec == "hevc" && !caps.hevcMain10) add(buildJsonObject {
                            put("Condition", "LessThanEqual"); put("Property", "VideoBitDepth"); put("Value", "8"); put("IsRequired", false)
                        })
                    })
                })
                add(buildJsonObject {
                    put("Type", "Video"); put("Codec", "h264")
                    put("Conditions", buildJsonArray {
                        add(buildJsonObject { put("Condition", "LessThanEqual"); put("Property", "VideoBitDepth"); put("Value", "8"); put("IsRequired", false) })
                    })
                })
                add(buildJsonObject {
                    put("Type", "Video")
                    put("Conditions", buildJsonArray {
                        add(buildJsonObject { put("Condition", "LessThanEqual"); put("Property", "Width"); put("Value", "${caps.maxWidth}"); put("IsRequired", false) })
                    })
                })
            })
            // Intégrés : texte et image (Media3 les lit dans MKV/MP4). Hors flux : SRT, ASS, VTT servis à part.
            put("SubtitleProfiles", subtitleProfiles(textSubtitles + bitmapSubtitles, listOf("srt", "subrip", "ass", "ssa", "vtt", "webvtt")))
        }
    }

    /** Valeurs Jellyfin de VideoRangeType que le lecteur natif affiche correctement. */
    fun nativeVideoRangeTypes(caps: DeviceCapabilities): List<String> {
        val hdr10 = DynamicRange.Hdr10 in caps.ranges
        val hlg = DynamicRange.Hlg in caps.ranges
        val dv = caps.supportsDolbyVision
        return buildList {
            add("SDR")
            if (hdr10) addAll(listOf("HDR10", "HDR10Plus", "DOVIInvalid"))
            if (hlg) add("HLG")
            if (dv) {
                addAll(listOf("DOVI", "DOVIWithSDR"))
                if (hdr10) addAll(listOf("DOVIWithHDR10", "DOVIWithHDR10Plus", "DOVIWithEL", "DOVIWithELHDR10Plus"))
                if (hlg) add("DOVIWithHLG")
            } else if (hdr10) {
                // Sans décodeur DV : la couche de base HDR10 des profils 7/8 est lue telle quelle.
                addAll(listOf("DOVIWithHDR10", "DOVIWithHDR10Plus", "DOVIWithEL", "DOVIWithELHDR10Plus"))
            }
        }
    }
}

