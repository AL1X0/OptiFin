package app.optifin.tv.ui.settings

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Logout
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.CleaningServices
import androidx.compose.material.icons.rounded.CloudUpload
import androidx.compose.material.icons.rounded.DeleteSweep
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.SystemUpdate
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Icon
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Switch
import androidx.tv.material3.Text
import app.optifin.tv.AppServices
import app.optifin.tv.core.AppLog
import app.optifin.tv.core.LogLevel
import app.optifin.tv.core.api.userMessage
import app.optifin.tv.core.media.ImageUrls
import app.optifin.tv.core.playback.EnginePreference
import app.optifin.tv.core.playback.ImageSubtitlePolicy
import app.optifin.tv.core.settings.AppSettings
import app.optifin.tv.core.settings.BitrateChoices
import app.optifin.tv.core.settings.PreferredLanguages
import app.optifin.tv.core.settings.SubtitleBackground
import app.optifin.tv.core.settings.SubtitleMode
import app.optifin.tv.core.update.AppUpdater
import app.optifin.tv.ui.components.Avatar
import app.optifin.tv.ui.components.MenuRow
import app.optifin.tv.ui.components.TvButton
import app.optifin.tv.ui.components.TvDialog
import app.optifin.tv.ui.shell.AppNav
import app.optifin.tv.ui.theme.OF
import coil3.SingletonImageLoader
import kotlinx.coroutines.launch
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody

private data class Choice<T>(val title: String, val options: List<Pair<T, String>>, val current: T, val apply: (AppSettings, T) -> AppSettings)

@Composable
private fun SectionTitle(text: String) {
    Text(text, style = MaterialTheme.typography.titleMedium, color = OF.TextTertiary, modifier = Modifier.padding(start = 12.dp, top = 22.dp, bottom = 6.dp))
}

@Composable
private fun SwitchRow(label: String, supporting: String?, checked: Boolean, onToggle: () -> Unit) {
    MenuRow(label, onToggle, supporting = supporting, trailing = { Switch(checked = checked, onCheckedChange = { onToggle() }) })
}

/** Réglages : lecture, sous-titres, langues, écran d'accueil Android TV, application. */
@Composable
fun SettingsScreen(nav: AppNav) {
    val settings by AppServices.settings.settings.collectAsState()
    var choice by remember { mutableStateOf<Choice<*>?>(null) }
    var dialog by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val first = remember { FocusRequester() }
    fun update(transform: (AppSettings) -> AppSettings) = AppServices.settings.update(transform)

    Column(Modifier.fillMaxSize().padding(top = OF.SafeY + 8.dp)) {
        Text("Réglages", style = MaterialTheme.typography.displaySmall, modifier = Modifier.padding(start = OF.Gutter, bottom = 8.dp))
        LazyColumn(Modifier.fillMaxWidth().padding(horizontal = OF.Gutter - 12.dp).width(900.dp), contentPadding = PaddingValues(bottom = 64.dp)) {
            item { SectionTitle("Lecture") }
            item {
                MenuRow("Lecteur", {
                    choice = Choice("Lecteur", EnginePreference.entries.map { it to it.label }, settings.enginePreference) { s, v -> s.copy(enginePreference = v) }
                }, Modifier.focusRequester(first), supporting = settings.enginePreference.label + when (settings.enginePreference) {
                    EnginePreference.Auto -> " — natif (HDR, Dolby Vision) ou mpv selon le fichier"
                    EnginePreference.Native -> " — Media3, transcodage si nécessaire"
                    EnginePreference.Mpv -> " — libmpv pour tout"
                })
            }
            item {
                MenuRow("Débit maximal", {
                    choice = Choice("Débit maximal", BitrateChoices.entries.map { it.key to it.value }, settings.maxBitrate) { s, v -> s.copy(maxBitrate = v) }
                }, supporting = BitrateChoices[settings.maxBitrate] ?: "${settings.maxBitrate / 1_000_000} Mb/s")
            }
            item {
                MenuRow("Sous-titres image (PGS, VobSub)", {
                    choice = Choice("Sous-titres image", ImageSubtitlePolicy.entries.map { it to it.label }, settings.imageSubtitles) { s, v -> s.copy(imageSubtitles = v) }
                }, supporting = settings.imageSubtitles.label + " — quand ils ne peuvent pas rester dans le flux")
            }
            item { SwitchRow("Épisode suivant automatique", "Lance l’épisode suivant à la fin du générique", settings.autoPlayNext) { update { it.copy(autoPlayNext = !it.autoPlayNext) } } }
            item { SwitchRow("Passer les intros automatiquement", "Intros, récapitulatifs et génériques détectés par le serveur", settings.autoSkipSegments) { update { it.copy(autoSkipSegments = !it.autoSkipSegments) } } }

            item { SectionTitle("Langues et sous-titres") }
            item {
                MenuRow("Langue audio préférée", {
                    choice = Choice("Langue audio", listOf<Pair<String?, String>>(null to "Réglage du serveur") + PreferredLanguages.entries.map { it.key to it.value },
                        settings.audioLanguage) { s, v -> s.copy(audioLanguage = v) }
                }, supporting = settings.audioLanguage?.let { PreferredLanguages[it] } ?: "Réglage du serveur")
            }
            item {
                MenuRow("Sous-titres", {
                    choice = Choice("Sous-titres", SubtitleMode.entries.map { it to it.label }, settings.subtitleMode) { s, v -> s.copy(subtitleMode = v) }
                }, supporting = settings.subtitleMode.label)
            }
            item {
                MenuRow("Langue des sous-titres", {
                    choice = Choice("Langue des sous-titres", listOf<Pair<String?, String>>(null to "Réglage du serveur") + PreferredLanguages.entries.map { it.key to it.value },
                        settings.subtitleLanguage) { s, v -> s.copy(subtitleLanguage = v) }
                }, supporting = settings.subtitleLanguage?.let { PreferredLanguages[it] } ?: "Réglage du serveur")
            }
            item {
                MenuRow("Taille des sous-titres", {
                    choice = Choice("Taille des sous-titres", listOf(0.8f to "Petite", 1f to "Normale", 1.2f to "Grande", 1.45f to "Très grande"),
                        settings.subtitleScale) { s, v -> s.copy(subtitleScale = v) }
                }, supporting = when { settings.subtitleScale < 0.9f -> "Petite"; settings.subtitleScale < 1.1f -> "Normale"; settings.subtitleScale < 1.3f -> "Grande"; else -> "Très grande" })
            }
            item {
                MenuRow("Style des sous-titres", {
                    choice = Choice("Style des sous-titres", SubtitleBackground.entries.map { it to it.label }, settings.subtitleBackground) { s, v -> s.copy(subtitleBackground = v) }
                }, supporting = settings.subtitleBackground.label)
            }

            item { SectionTitle("Écran d’accueil Android TV") }
            item { SwitchRow("« Continuer à regarder »", "Vos lectures en cours sur l’écran d’accueil du téléviseur", settings.watchNext) { update { it.copy(watchNext = !it.watchNext) } } }

            item { SectionTitle("Application") }
            item { MenuRow("Rechercher une mise à jour", { dialog = "update" }, icon = Icons.Rounded.SystemUpdate, supporting = "Version ${AppServices.version}") }
            item {
                MenuRow("Vider le cache", {
                    scope.launch {
                        SingletonImageLoader.get(AppServices.context).let { it.memoryCache?.clear(); it.diskCache?.clear() }
                        AppServices.home?.clearCache()
                        AppServices.notice("Cache vidé")
                    }
                }, icon = Icons.Rounded.CleaningServices, supporting = "Images et accueil enregistrés")
            }
            item { MenuRow("Journaux", { nav.logs() }, icon = Icons.Rounded.Description, supporting = "Diagnostic de lecture et de connexion") }
            item { SwitchRow("Mode debug", "Journal détaillé et informations de lecture dans le lecteur", settings.debugMode) { update { it.copy(debugMode = !it.debugMode) } } }
            item { MenuRow("À propos", { dialog = "about" }, icon = Icons.Rounded.Info, supporting = "OptiFin TV ${AppServices.version} · ${AppServices.capabilities.model}") }
        }
    }
    LaunchedEffect(Unit) { runCatching { first.requestFocus() } }

    choice?.let { c -> ChoiceDialog(c, onDismiss = { choice = null }) }
    when (dialog) {
        "update" -> UpdateDialog { dialog = null }
        "about" -> TvDialog("OptiFin TV", { dialog = null }, subtitle = "Version ${AppServices.version}") {
            Text(
                "Client Jellyfin pour Android TV.\n\nAppareil : ${AppServices.capabilities.summary}\n\n" +
                    "Bibliothèques : Jetpack Compose for TV, Media3 (Apache 2.0), extension FFmpeg de Jellyfin (LGPL/GPL), " +
                    "libmpv (LGPL), OkHttp, Coil, kotlinx.serialization (Apache 2.0).",
                style = MaterialTheme.typography.bodyMedium, color = OF.TextSecondary,
            )
            Spacer(Modifier.height(16.dp))
            TvButton("Fermer", { dialog = null }, primary = true)
        }
    }
}

@Suppress("UNCHECKED_CAST")
@Composable
private fun <T> ChoiceDialog(choice: Choice<T>, onDismiss: () -> Unit) {
    val focus = remember { FocusRequester() }
    TvDialog(choice.title, onDismiss) {
        LazyColumn(Modifier.heightIn(max = 520.dp)) {
            items(choice.options) { (value, label) ->
                val selected = value == choice.current
                MenuRow(label, {
                    AppServices.settings.update { choice.apply(it, value) }
                    onDismiss()
                }, if (selected) Modifier.focusRequester(focus) else Modifier, selected = selected,
                    trailing = if (selected) { { Icon(Icons.Rounded.Check, null) } } else null)
            }
        }
    }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
}

/** Mise à jour : dernière version publiée sur GitHub, téléchargement puis installation. */
@Composable
private fun UpdateDialog(onDismiss: () -> Unit) {
    var state by remember { mutableStateOf("Recherche d’une mise à jour…") }
    var update by remember { mutableStateOf<AppUpdater.Update?>(null) }
    var progress by remember { mutableStateOf<Float?>(null) }
    val scope = rememberCoroutineScope()
    LaunchedEffect(Unit) {
        try {
            val found = AppUpdater.check()
            update = found
            state = if (found == null) "OptiFin TV est à jour (${AppServices.version})." else "Version ${found.version} disponible (${found.sizeMb} Mo)."
        } catch (e: Exception) {
            state = e.userMessage()
        }
    }
    TvDialog("Mise à jour", onDismiss) {
        Text(state, style = MaterialTheme.typography.bodyLarge, color = OF.TextSecondary)
        progress?.let { Text("Téléchargement : ${(it * 100).toInt()} %", style = MaterialTheme.typography.bodyMedium, color = OF.TextTertiary) }
        Spacer(Modifier.height(16.dp))
        val u = update
        if (u != null && progress == null) {
            TvButton("Installer", {
                progress = 0f
                scope.launch {
                    try {
                        AppUpdater.install(AppServices.context, u) { progress = it }
                    } catch (e: Exception) {
                        state = e.userMessage()
                        progress = null
                    }
                }
            }, primary = true)
        } else {
            TvButton("Fermer", onDismiss, primary = u == null)
        }
    }
}

/** Compte : profil actif, autres comptes (bascule), ajout, déconnexion. */
@Composable
fun AccountScreen(nav: AppNav) {
    val session by AppServices.session.collectAsState()
    val scope = rememberCoroutineScope()
    val accounts = remember(session) { AppServices.accounts.accounts().filter { it.account.id != session?.account?.id } }
    val first = remember { FocusRequester() }
    Column(Modifier.fillMaxSize().padding(top = OF.SafeY + 8.dp, start = OF.Gutter - 12.dp, end = OF.Gutter)) {
        Text("Compte", style = MaterialTheme.typography.displaySmall, modifier = Modifier.padding(start = 12.dp, bottom = 16.dp))
        session?.let { s ->
            Row(Modifier.padding(start = 12.dp, bottom = 12.dp), horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                Avatar(s.account.userName, AppServices.images?.userAvatar(s.account.userId, 200, s.account.avatarTag), 84.dp)
                Column {
                    Text(s.account.userName, style = MaterialTheme.typography.headlineMedium)
                    Text("${s.server.name} · Jellyfin ${s.server.version}", style = MaterialTheme.typography.bodyMedium, color = OF.TextSecondary)
                    Text(s.server.baseUrl, style = MaterialTheme.typography.bodySmall, color = OF.TextTertiary)
                }
            }
        }
        LazyColumn(Modifier.width(900.dp)) {
            if (accounts.isNotEmpty()) item { SectionTitle("Changer de compte") }
            items(accounts, key = { it.account.id }) { a ->
                MenuRow(a.account.userName, {
                    if (AppServices.switchTo(a.account.id)) AppServices.notice("Connecté en tant que ${a.account.userName}")
                    else {
                        app.optifin.tv.ui.auth.AuthFlow.pendingServer = a.server
                        app.optifin.tv.ui.auth.AuthFlow.presetUser = a.account.userName
                        nav.addAccount()
                    }
                }, if (a == accounts.first()) Modifier.focusRequester(first) else Modifier, supporting = a.server.name, trailing = {
                    Avatar(a.account.userName, ImageUrls(a.server.baseUrl).userAvatar(a.account.userId, 96, a.account.avatarTag), 36.dp)
                })
            }
            item { SectionTitle("Gérer") }
            item { MenuRow("Ajouter un compte", nav.addAccount, if (accounts.isEmpty()) Modifier.focusRequester(first) else Modifier, Icons.Rounded.Add, supporting = "Autre utilisateur ou autre serveur") }
            item { MenuRow("Se déconnecter", { scope.launch { AppServices.signOut() } }, icon = Icons.AutoMirrored.Rounded.Logout, supporting = "Le compte reste proposé à la connexion") }
        }
    }
    LaunchedEffect(Unit) { runCatching { first.requestFocus() } }
}

/** Journaux : niveau, envoi au serveur Jellyfin (récupérables depuis le tableau de bord), effacement. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun LogsScreen(@Suppress("UNUSED_PARAMETER") nav: AppNav) {
    val entries by AppLog.entries.collectAsState()
    var level by remember { mutableStateOf(LogLevel.Debug) }
    val scope = rememberCoroutineScope()
    val list = rememberLazyListState()
    val shown = entries.filter { it.level >= level }
    LaunchedEffect(shown.size) { if (shown.isNotEmpty()) list.scrollToItem(shown.lastIndex) }
    Column(Modifier.fillMaxSize().padding(top = OF.SafeY + 8.dp, start = OF.Gutter, end = OF.Gutter)) {
        Text("Journaux", style = MaterialTheme.typography.displaySmall, maxLines = 1)
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            for (l in listOf(LogLevel.Debug to "Tout", LogLevel.Info to "Infos", LogLevel.Warning to "Avertissements", LogLevel.Error to "Erreurs")) {
                TvButton(l.second, { level = l.first }, primary = level == l.first)
            }
            TvButton("Envoyer", {
                val client = AppServices.client ?: return@TvButton
                scope.launch {
                    try {
                        val text = (AppLog.logFile?.takeIf { it.exists() }?.readText() ?: AppLog.text()).takeLast(900_000)
                        val r = client.send("POST", "ClientLog/Document", emptyList(), text.toRequestBody("text/plain".toMediaType()))
                        val name = Regex("\"FileName\"\\s*:\\s*\"([^\"]+)\"").find(r)?.groupValues?.get(1)
                        AppServices.notice("Journal envoyé au serveur${name?.let { " : $it" } ?: ""}")
                    } catch (e: Exception) {
                        AppServices.notice(e.userMessage())
                    }
                }
            }, icon = Icons.Rounded.CloudUpload)
            Spacer(Modifier.weight(1f))
            TvButton("Effacer", { AppLog.clear() }, icon = Icons.Rounded.DeleteSweep)
        }
        Spacer(Modifier.height(14.dp))
        LazyColumn(state = list, modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(14.dp)).background(Color(0xFF0B0B0D)).padding(16.dp)) {
            items(shown.size) { i -> LogLine(shown[i]) }
        }
    }
}

/** Ligne du journal, focalisable (la télécommande fait défiler le journal ligne à ligne). */
@Composable
private fun LogLine(e: app.optifin.tv.core.LogEntry) {
    var focused by remember { mutableStateOf(false) }
    Text(
        e.toString(), fontFamily = FontFamily.Monospace, fontSize = 13.sp, lineHeight = 18.sp,
        color = when (e.level) { LogLevel.Error -> OF.Danger; LogLevel.Warning -> Color(0xFFFFCC66); LogLevel.Info -> OF.TextPrimary; LogLevel.Debug -> OF.TextTertiary },
        modifier = Modifier.fillMaxWidth()
            .background(if (focused) Color(0x26FFFFFF) else Color.Transparent)
            .onFocusChanged { focused = it.isFocused }
            .focusable(),
    )
}
