package app.optifin.tv.core.settings

import app.optifin.tv.core.L
import app.optifin.tv.core.AppLog
import app.optifin.tv.core.api.JellyfinJson
import app.optifin.tv.core.playback.EnginePreference
import app.optifin.tv.core.playback.ImageSubtitlePolicy
import java.io.File
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.Serializable

/** Comportement des sous-titres au démarrage d'une lecture. */
enum class SubtitleMode(val label: String) {
    Server(L.t("Réglage du serveur")),
    Always(L.t("Toujours")),
    ForcedOnly(L.t("Forcés uniquement")),
    None(L.t("Jamais")),
}

enum class SubtitleBackground(val label: String) { None(L.t("Contour")), Shadow(L.t("Ombre")), Box(L.t("Bandeau")) }

/** Langues proposées (code ISO 639-2 utilisé par Jellyfin). */
val PreferredLanguages = linkedMapOf(
    "fre" to L.t("Français"), "eng" to L.t("Anglais"), "spa" to L.t("Espagnol"), "ger" to L.t("Allemand"), "ita" to L.t("Italien"),
    "por" to L.t("Portugais"), "jpn" to L.t("Japonais"), "kor" to L.t("Coréen"), "chi" to L.t("Chinois"), "rus" to L.t("Russe"),
    "ara" to L.t("Arabe"), "dut" to L.t("Néerlandais"),
)

/** Débits proposés (bits/s). 0 = pas de limite côté client (le serveur plafonne). */
val BitrateChoices = linkedMapOf(
    0L to "Maximum", 120_000_000L to "120 Mb/s (4K)", 60_000_000L to "60 Mb/s", 40_000_000L to "40 Mb/s (1080p)",
    20_000_000L to "20 Mb/s", 10_000_000L to "10 Mb/s (720p)", 4_000_000L to "4 Mb/s", 1_500_000L to "1,5 Mb/s",
)

@Serializable
data class AppSettings(
    val debugMode: Boolean = false,
    val maxBitrate: Long = 0,
    val audioLanguage: String? = null,
    val subtitleLanguage: String? = null,
    val subtitleMode: SubtitleMode = SubtitleMode.Server,
    val subtitleScale: Float = 1f,
    val subtitleBackground: SubtitleBackground = SubtitleBackground.None,
    val enginePreference: EnginePreference = EnginePreference.Auto,
    val imageSubtitles: ImageSubtitlePolicy = ImageSubtitlePolicy.Auto,
    val autoSkipSegments: Boolean = false,
    val autoPlayNext: Boolean = true,
    /** Rangée « Continuer à regarder » de l'écran d'accueil Android TV. */
    val watchNext: Boolean = true,
) {
    /** Débit maximal effectif (0 = « Maximum » → 200 Mb/s, le serveur plafonne). */
    val effectiveMaxBitrate: Long get() = if (maxBitrate <= 0) 200_000_000 else maxBitrate
}

/** Réglages persistés (fichier JSON privé), observables. */
class SettingsStore(private val file: File) {
    private val _settings = MutableStateFlow(read())
    val settings: StateFlow<AppSettings> = _settings
    val value: AppSettings get() = _settings.value

    private fun read(): AppSettings = try {
        if (file.exists()) JellyfinJson.decodeFromString(AppSettings.serializer(), file.readText()) else AppSettings()
    } catch (e: Exception) {
        AppLog.w("settings", "Réglages illisibles : ${e.message}")
        AppSettings()
    }

    fun update(transform: (AppSettings) -> AppSettings) {
        val next = transform(_settings.value)
        _settings.value = next
        AppLog.verbose = next.debugMode
        try {
            file.parentFile?.mkdirs()
            file.writeText(JellyfinJson.encodeToString(AppSettings.serializer(), next))
        } catch (e: Exception) {
            AppLog.w("settings", "Réglages non enregistrés : ${e.message}")
        }
    }
}
