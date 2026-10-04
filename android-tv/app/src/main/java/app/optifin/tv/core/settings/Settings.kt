package app.optifin.tv.core.settings

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
    Server("Réglage du serveur"),
    Always("Toujours"),
    ForcedOnly("Forcés uniquement"),
    None("Jamais"),
}

enum class SubtitleBackground(val label: String) { None("Contour"), Shadow("Ombre"), Box("Bandeau") }

/** Langues proposées (code ISO 639-2 utilisé par Jellyfin). */
val PreferredLanguages = linkedMapOf(
    "fre" to "Français", "eng" to "Anglais", "spa" to "Espagnol", "ger" to "Allemand", "ita" to "Italien",
    "por" to "Portugais", "jpn" to "Japonais", "kor" to "Coréen", "chi" to "Chinois", "rus" to "Russe",
    "ara" to "Arabe", "dut" to "Néerlandais",
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
