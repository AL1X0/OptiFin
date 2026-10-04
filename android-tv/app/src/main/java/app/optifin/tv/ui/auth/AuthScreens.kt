package app.optifin.tv.ui.auth

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Dns
import androidx.compose.material.icons.rounded.Login
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Icon
import androidx.tv.material3.ListItem
import androidx.tv.material3.ListItemDefaults
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Surface
import androidx.tv.material3.SurfaceDefaults
import androidx.tv.material3.Text
import app.optifin.tv.AppServices
import app.optifin.tv.R
import app.optifin.tv.core.api.userMessage
import app.optifin.tv.core.auth.DiscoveredServer
import app.optifin.tv.core.auth.JellyfinServer
import app.optifin.tv.core.auth.PublicUser
import app.optifin.tv.core.auth.ServerDiscovery
import app.optifin.tv.core.auth.StoredAccount
import app.optifin.tv.core.media.ImageUrls
import app.optifin.tv.ui.components.Avatar
import app.optifin.tv.ui.components.TvButton
import app.optifin.tv.ui.components.TvTextField
import app.optifin.tv.ui.theme.OF
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/** Serveur choisi sur le premier écran, utilisé par l'écran de connexion. */
object AuthFlow {
    var pendingServer: JellyfinServer? = null
    var presetUser: String? = null
}

/** Mise en page des écrans de connexion : marque à gauche, choix à droite (focus dans la colonne). */
@Composable
private fun AuthLayout(title: String, subtitle: String, footer: String? = null, content: @Composable () -> Unit) {
    Box(
        Modifier.fillMaxSize().background(
            Brush.radialGradient(listOf(Color(0xFF10233D), Color(0xFF05070B), Color.Black), radius = 1600f),
        ),
    ) {
        Row(Modifier.fillMaxSize().padding(horizontal = 96.dp, vertical = 56.dp), horizontalArrangement = Arrangement.spacedBy(80.dp)) {
            Column(Modifier.weight(1f).fillMaxHeight(), verticalArrangement = Arrangement.Center) {
                Image(painterResource(R.drawable.logo_full), null, Modifier.size(132.dp))
                Spacer(Modifier.height(18.dp))
                Text(title, style = MaterialTheme.typography.displayMedium, color = OF.TextPrimary)
                Spacer(Modifier.height(12.dp))
                Text(subtitle, style = MaterialTheme.typography.bodyLarge, color = OF.TextSecondary)
                if (footer != null) {
                    Spacer(Modifier.height(28.dp))
                    Text(footer, style = MaterialTheme.typography.bodySmall, color = OF.TextTertiary)
                }
            }
            Column(Modifier.weight(1.1f).fillMaxHeight(), verticalArrangement = Arrangement.Center) { content() }
        }
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(text, style = MaterialTheme.typography.titleSmall, color = OF.TextTertiary, modifier = Modifier.padding(top = 18.dp, bottom = 8.dp))
}

@Composable
private fun ChoiceItem(title: String, subtitle: String?, leading: @Composable () -> Unit, onClick: () -> Unit, modifier: Modifier = Modifier) {
    ListItem(
        selected = false,
        onClick = onClick,
        modifier = modifier,
        headlineContent = { Text(title, style = MaterialTheme.typography.titleMedium) },
        supportingContent = subtitle?.let { { Text(it, style = MaterialTheme.typography.bodySmall) } },
        leadingContent = { leading() },
        colors = ListItemDefaults.colors(
            containerColor = Color(0x14FFFFFF), focusedContainerColor = Color.White,
            contentColor = OF.TextPrimary, focusedContentColor = Color.Black,
        ),
        shape = ListItemDefaults.shape(RoundedCornerShape(14.dp)),
    )
}

/** Premier écran : comptes enregistrés, serveurs du réseau, adresse. */
@Composable
fun ConnectScreen(onServer: () -> Unit, onSignedIn: () -> Unit) {
    val scope = rememberCoroutineScope()
    val accounts = remember { AppServices.accounts.accounts() }
    var discovered by remember { mutableStateOf<List<DiscoveredServer>>(emptyList()) }
    var searching by remember { mutableStateOf(true) }
    var address by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    val first = remember { FocusRequester() }

    LaunchedEffect(Unit) {
        ServerDiscovery.discover().collect { discovered = it }
        searching = false
    }

    fun connect(input: String) {
        if (busy || input.isBlank()) return
        busy = true
        error = null
        scope.launch {
            try {
                AuthFlow.pendingServer = AppServices.auth.probe(input)
                AuthFlow.presetUser = null
                onServer()
            } catch (e: Exception) {
                error = e.userMessage()
            } finally {
                busy = false
            }
        }
    }

    fun resume(stored: StoredAccount) {
        if (AppServices.switchTo(stored.account.id)) {
            onSignedIn()
        } else {
            // Jeton perdu : reconnexion à ce serveur, identifiant prérempli.
            AuthFlow.pendingServer = stored.server
            AuthFlow.presetUser = stored.account.userName
            onServer()
        }
    }

    AuthLayout("OptiFin", "Connectez-vous à votre serveur Jellyfin.") {
        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            if (accounts.isNotEmpty()) {
                item { SectionLabel("Comptes") }
                items(accounts, key = { it.account.id }) { a ->
                    val images = ImageUrls(a.server.baseUrl)
                    ChoiceItem(
                        a.account.userName, a.server.name,
                        leading = { Avatar(a.account.userName, images.userAvatar(a.account.userId, 96, a.account.avatarTag), 40.dp) },
                        onClick = { resume(a) },
                        modifier = if (a == accounts.first()) Modifier.focusRequester(first) else Modifier,
                    )
                }
            }
            item { SectionLabel(if (searching) "Recherche sur ce réseau…" else "Sur ce réseau") }
            if (discovered.isEmpty() && !searching) {
                item { Text("Aucun serveur détecté automatiquement.", style = MaterialTheme.typography.bodyMedium, color = OF.TextTertiary) }
            }
            items(discovered, key = { it.id }) { s ->
                ChoiceItem(s.name, s.address, leading = { Icon(Icons.Rounded.Dns, null) }, onClick = { connect(s.address) },
                    modifier = if (accounts.isEmpty() && s == discovered.first()) Modifier.focusRequester(first) else Modifier)
            }
            item { SectionLabel("Adresse du serveur") }
            item {
                TvTextField(address, { address = it }, "https://jellyfin.exemple.fr", keyboardType = KeyboardType.Uri, imeAction = ImeAction.Go,
                    onSubmit = { connect(address) }, focusRequester = if (accounts.isEmpty() && discovered.isEmpty()) first else remember { FocusRequester() })
            }
            item {
                Spacer(Modifier.height(10.dp))
                TvButton(if (busy) "Connexion…" else "Continuer", { connect(address) }, primary = true, enabled = !busy, modifier = Modifier.fillMaxWidth())
            }
            error?.let { item { Text(it, style = MaterialTheme.typography.bodyMedium, color = OF.Danger, modifier = Modifier.padding(top = 8.dp)) } }
        }
    }
    LaunchedEffect(accounts.size, discovered.isNotEmpty()) { runCatching { first.requestFocus() } }
}

/** Connexion à un serveur : Quick Connect (le plus simple sur TV), profils, mot de passe. */
@Composable
fun LoginScreen(onSignedIn: () -> Unit, onBack: () -> Unit) {
    val server = AuthFlow.pendingServer ?: run {
        LaunchedEffect(Unit) { onBack() }
        return
    }
    val scope = rememberCoroutineScope()
    var users by remember { mutableStateOf<List<PublicUser>>(emptyList()) }
    var quickConnect by remember { mutableStateOf(false) }
    var username by remember { mutableStateOf(AuthFlow.presetUser ?: "") }
    var password by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    var code by remember { mutableStateOf<String?>(null) }
    var quickJob by remember { mutableStateOf<Job?>(null) }
    val firstFocus = remember { FocusRequester() }
    val passwordFocus = remember { FocusRequester() }

    LaunchedEffect(server) {
        users = AppServices.auth.publicUsers(server)
        quickConnect = AppServices.auth.isQuickConnectEnabled(server)
    }
    LaunchedEffect(quickConnect, users.size) { runCatching { firstFocus.requestFocus() } }

    BackHandler(enabled = code != null) {
        quickJob?.cancel()
        code = null
    }

    fun finish(session: app.optifin.tv.core.auth.ActiveSession) {
        AppServices.signIn(session)
        onSignedIn()
    }

    fun login() {
        if (busy || username.isBlank()) return
        busy = true
        error = null
        scope.launch {
            try {
                finish(AppServices.auth.login(server, username.trim(), password))
            } catch (e: Exception) {
                error = e.userMessage()
            } finally {
                busy = false
            }
        }
    }

    fun startQuickConnect() {
        error = null
        quickJob = scope.launch {
            try {
                val ticket = AppServices.auth.initiateQuickConnect(server)
                code = ticket.code
                finish(AppServices.auth.awaitQuickConnect(server, ticket))
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e
            } catch (e: Exception) {
                error = e.userMessage()
                code = null
            }
        }
    }

    val shown = code
    AuthLayout(server.name, if (quickConnect) "Le plus simple : Quick Connect." else "Qui regarde ?", "${server.baseUrl} · Jellyfin ${server.version}") {
        if (shown != null) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                Text("Code Quick Connect", style = MaterialTheme.typography.titleLarge, color = OF.TextSecondary)
                Spacer(Modifier.height(16.dp))
                Surface(shape = RoundedCornerShape(20.dp), colors = SurfaceDefaults.colors(containerColor = Color(0x1FFFFFFF))) {
                    Text(shown, fontSize = 64.sp, fontFamily = FontFamily.Monospace, color = OF.TextPrimary,
                        modifier = Modifier.padding(horizontal = 40.dp, vertical = 18.dp), letterSpacing = 8.sp)
                }
                Spacer(Modifier.height(20.dp))
                Text(
                    "Sur votre téléphone ou ordinateur : Jellyfin › Profil › Quick Connect, puis saisissez ce code.",
                    style = MaterialTheme.typography.bodyLarge, color = OF.TextSecondary,
                )
                Spacer(Modifier.height(24.dp))
                TvButton("Annuler", { quickJob?.cancel(); code = null }, modifier = Modifier.focusRequester(firstFocus))
            }
            LaunchedEffect(Unit) { runCatching { firstFocus.requestFocus() } }
            return@AuthLayout
        }
        LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (quickConnect) {
                item {
                    TvButton("Se connecter avec Quick Connect", ::startQuickConnect, icon = Icons.Rounded.Bolt, primary = true,
                        modifier = Modifier.fillMaxWidth().focusRequester(firstFocus))
                }
                item {
                    Text("Un code s’affiche : validez-le depuis Jellyfin sur votre téléphone.", style = MaterialTheme.typography.bodySmall, color = OF.TextTertiary)
                }
                item { SectionLabel("Ou avec un mot de passe") }
            }
            if (users.isNotEmpty()) {
                item {
                    val images = ImageUrls(server.baseUrl)
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        items(users, key = { it.id }) { u ->
                            Surface(
                                onClick = {
                                    username = u.name
                                    if (!u.hasPassword) login() else runCatching { passwordFocus.requestFocus() }
                                },
                                shape = androidx.tv.material3.ClickableSurfaceDefaults.shape(RoundedCornerShape(16.dp)),
                                colors = androidx.tv.material3.ClickableSurfaceDefaults.colors(
                                    containerColor = if (username == u.name) Color(0x33FFFFFF) else Color(0x14FFFFFF),
                                    focusedContainerColor = Color.White, focusedContentColor = Color.Black,
                                ),
                                modifier = if (!quickConnect && u == users.first()) Modifier.focusRequester(firstFocus) else Modifier,
                            ) {
                                Column(Modifier.padding(14.dp).width(96.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                    Avatar(u.name, u.avatarTag?.let { images.userAvatar(u.id, 160, it) }, 64.dp)
                                    Spacer(Modifier.height(8.dp))
                                    Text(u.name, style = MaterialTheme.typography.titleSmall, maxLines = 1)
                                }
                            }
                        }
                    }
                }
            }
            item {
                TvTextField(username, { username = it }, "Nom d’utilisateur", imeAction = ImeAction.Next,
                    focusRequester = if (!quickConnect && users.isEmpty()) firstFocus else remember { FocusRequester() })
            }
            item { TvTextField(password, { password = it }, "Mot de passe", password = true, imeAction = ImeAction.Go, onSubmit = ::login, focusRequester = passwordFocus) }
            item {
                TvButton(if (busy) "Connexion…" else "Se connecter", ::login, icon = Icons.Rounded.Login, primary = !quickConnect,
                    enabled = !busy, modifier = Modifier.fillMaxWidth())
            }
            error?.let { item { Text(it, style = MaterialTheme.typography.bodyMedium, color = OF.Danger) } }
        }
    }
}

