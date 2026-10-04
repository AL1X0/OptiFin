package app.optifin.tv.core.media

import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.util.Locale
import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.roundToInt

/** Mise en forme des métadonnées (mêmes règles que sur iPhone, Android et PC). */
object MediaFormat {
    private val rating = DecimalFormat("0.0", DecimalFormatSymbols(Locale.FRANCE))

    /** « 2 h 14 min », « 48 min » ; null si moins d'une minute. */
    fun duration(ms: Long?): String? {
        if (ms == null) return null
        val totalMinutes = (ms / 60_000).toInt()
        if (totalMinutes <= 0) return null
        val h = totalMinutes / 60
        val m = totalMinutes % 60
        return when {
            h == 0 -> "$m min"
            m == 0 -> "$h h"
            else -> "$h h ${m.toString().padStart(2, '0')} min"
        }
    }

    /** « 1:02:03 » / « 12:34 ». */
    fun clock(ms: Long): String {
        val total = (ms.coerceAtLeast(0) / 1000).toInt()
        val h = total / 3600
        val m = total / 60 % 60
        val s = total % 60
        return if (h > 0) "$h:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}" else "$m:${s.toString().padStart(2, '0')}"
    }

    /** Années d'une série : « 2016 – 2022 », « 2019 – » (en cours). */
    fun years(item: MediaItem): String? {
        val start = item.year ?: item.premiereDate?.year ?: return null
        if (item.kind != MediaKind.Series) return start.toString()
        if (item.status == "Continuing") return "$start –"
        val end = item.endDate?.year
        return if (end == null || end == start) start.toString() else "$start – $end"
    }

    fun rating(r: Double?): String? = if (r != null && r > 0) rating.format(r) else null

    /** « 2021 · 2 h 35 min · 12 · ★ 8,1 ». */
    fun metadataLine(item: MediaItem): List<String> {
        val parts = mutableListOf<String>()
        years(item)?.let(parts::add)
        val seasons = item.childCount
        if (item.kind == MediaKind.Series && seasons != null) parts.add("$seasons saison${if (seasons > 1) "s" else ""}")
        else duration(item.runtimeMs)?.let(parts::add)
        item.officialRating?.takeIf { it.isNotEmpty() }?.let(parts::add)
        rating(item.communityRating)?.let { parts.add("★ $it") }
        return parts
    }

    /** « 1 h 12 min restantes ». */
    fun remaining(item: MediaItem): String? {
        val total = item.runtimeMs ?: return null
        if (item.user.positionTicks <= 0) return null
        return duration(total - item.resumeMs)?.let { "$it restantes" }
    }

    /** « 12,5 Mb/s ». */
    fun bitrate(bps: Long?): String? = bps?.let { if (it >= 10_000_000) "${it / 1_000_000} Mb/s" else "${"%.1f".format(Locale.FRANCE, it / 1e6)} Mb/s" }
}

/** Badges qualité : résolution, dynamique, audio, canaux (un par catégorie). */
object QualityBadges {
    fun forStreams(streams: List<StreamSummary>): List<String> {
        val video = streams.firstOrNull { it.isVideo }
        val audios = streams.filter { !it.isVideo }
        val badges = mutableListOf<String>()
        if (video != null) {
            resolutionLabel(video.width, video.height)?.let(badges::add)
            when (video.videoRange) {
                VideoRange.DolbyVision -> badges.add("Dolby Vision")
                VideoRange.Hdr10Plus -> badges.add("HDR10+")
                VideoRange.Hdr10 -> badges.add("HDR10")
                VideoRange.Hlg -> badges.add("HLG")
                VideoRange.Sdr -> {}
            }
        }
        bestAudio(audios)?.let(badges::add)
        when (audios.maxOfOrNull { it.channels ?: 0 } ?: 0) {
            6 -> badges.add("5.1")
            8 -> badges.add("7.1")
        }
        return badges
    }

    /** 4K / 1080p / 720p / SD, en tolérant les formats recadrés (2.39:1). */
    fun resolutionLabel(width: Int?, height: Int?): String? {
        if (width == null || height == null || width <= 0 || height <= 0) return null
        return when {
            width >= 3200 || height >= 2000 -> "4K"
            width >= 1800 || height >= 1000 -> "1080p"
            width >= 1200 || height >= 700 -> "720p"
            else -> "SD"
        }
    }

    private val ranking = listOf("Atmos", "DTS:X", "TrueHD", "DTS-HD MA", "DTS", "Dolby Digital+", "Dolby Digital")

    private fun bestAudio(audios: List<StreamSummary>): String? =
        audios.mapNotNull(::audioLabel).minByOrNull { ranking.indexOf(it) }

    fun audioLabel(a: StreamSummary): String? {
        if (a.spatial == SpatialAudio.Atmos) return "Atmos"
        if (a.spatial == SpatialAudio.DtsX) return "DTS:X"
        val profile = (a.profile ?: "").lowercase()
        return when (a.codec) {
            "truehd", "mlp" -> "TrueHD"
            "dts", "dca" -> if (profile.contains("ma") || profile.contains("hd")) "DTS-HD MA" else "DTS"
            "eac3" -> "Dolby Digital+"
            "ac3" -> "Dolby Digital"
            else -> null
        }
    }
}

/**
 * Couleur d'accent d'une illustration (mêmes règles que mobile et PC) : teinte vive dominante,
 * histogramme de 24 secteurs pondéré par la saturation.
 */
object Accent {
    private const val BUCKETS = 24

    /** Accent d'une image ARGB (pixels bruts, petite taille) ; null si quasi monochrome. */
    fun dominant(argb: IntArray): Int? {
        val weight = DoubleArray(BUCKETS)
        val r = DoubleArray(BUCKETS)
        val g = DoubleArray(BUCKETS)
        val b = DoubleArray(BUCKETS)
        for (px in argb) {
            if ((px ushr 24) < 128) continue
            val red = px shr 16 and 0xFF
            val green = px shr 8 and 0xFF
            val blue = px and 0xFF
            val (h, s, l) = toHsl(red, green, blue)
            if (l < 0.12 || l > 0.9 || s < 0.2) continue
            val bucket = floor(h / 360 * BUCKETS).toInt() % BUCKETS
            val w = s * (1 - abs(l - 0.5))
            weight[bucket] += w
            r[bucket] += red * w
            g[bucket] += green * w
            b[bucket] += blue * w
        }
        var best = 0
        for (i in 1 until BUCKETS) if (weight[i] > weight[best]) best = i
        if (weight[best] <= 0 || weight[best] < argb.size * 0.03 * 0.3) return null
        val total = weight[best]
        return normalize((r[best] / total).roundToInt(), (g[best] / total).roundToInt(), (b[best] / total).roundToInt())
    }

    /** Accent lisible sur fond noir : luminosité 0,55–0,72, saturation 0,35–0,85. */
    fun normalize(red: Int, green: Int, blue: Int): Int {
        val (h, s, l) = toHsl(red, green, blue)
        return fromHsl(h, s.coerceIn(0.35, 0.85), l.coerceIn(0.55, 0.72))
    }

    fun toHsl(red: Int, green: Int, blue: Int): Triple<Double, Double, Double> {
        val r = red / 255.0
        val g = green / 255.0
        val b = blue / 255.0
        val max = maxOf(r, g, b)
        val min = minOf(r, g, b)
        val delta = max - min
        val l = (max + min) / 2
        val s = if (delta == 0.0) 0.0 else delta / (1 - abs(2 * l - 1))
        var h = when {
            delta == 0.0 -> 0.0
            max == r -> 60 * (((g - b) / delta) % 6)
            max == g -> 60 * ((b - r) / delta + 2)
            else -> 60 * ((r - g) / delta + 4)
        }
        if (h < 0) h += 360
        return Triple(h, s, l)
    }

    fun fromHsl(h: Double, s: Double, l: Double): Int {
        val c = (1 - abs(2 * l - 1)) * s
        val x = c * (1 - abs(h / 60 % 2 - 1))
        val m = l - c / 2
        val (r, g, b) = when {
            h < 60 -> Triple(c, x, 0.0)
            h < 120 -> Triple(x, c, 0.0)
            h < 180 -> Triple(0.0, c, x)
            h < 240 -> Triple(0.0, x, c)
            h < 300 -> Triple(x, 0.0, c)
            else -> Triple(c, 0.0, x)
        }
        fun channel(v: Double) = ((v.coerceIn(0.0, 1.0)) * 255).roundToInt()
        return (0xFF shl 24) or (channel(r + m) shl 16) or (channel(g + m) shl 8) or channel(b + m)
    }
}
