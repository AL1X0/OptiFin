package app.optifin.tv.ui.player

import androidx.compose.foundation.focusGroup
import androidx.compose.ui.focus.focusProperties
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.ui.draw.alpha
import app.optifin.tv.core.L
import android.app.Activity
import android.graphics.Bitmap
import android.view.WindowManager
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.AspectRatio
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.ClosedCaption
import androidx.compose.material.icons.rounded.Forward10
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.List
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Replay10
import androidx.compose.material.icons.rounded.SkipNext
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.tv.material3.Button
import androidx.tv.material3.ButtonDefaults
import androidx.tv.material3.Icon
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import app.optifin.tv.AppServices
import app.optifin.tv.core.api.userMessage
import app.optifin.tv.core.media.MediaFormat
import app.optifin.tv.core.media.MediaKind
import app.optifin.tv.core.playback.EngineKind
import app.optifin.tv.core.playback.MediaTrack
import app.optifin.tv.core.playback.RemoteSubtitle
import app.optifin.tv.core.playback.TrackType
import app.optifin.tv.core.settings.PreferredLanguages
import app.optifin.tv.core.settings.SubtitleBackground
import app.optifin.tv.player.EngineState
import app.optifin.tv.player.PlayerController
import app.optifin.tv.player.PlayerPhase
import app.optifin.tv.player.PlayerUiState
import app.optifin.tv.player.VideoFit
import app.optifin.tv.ui.components.MenuRow
import app.optifin.tv.ui.components.TvButton
import app.optifin.tv.ui.theme.OF
import coil3.SingletonImageLoader
import coil3.compose.AsyncImage
import coil3.network.NetworkHeaders
import coil3.network.httpHeaders
import coil3.request.ImageRequest
import coil3.request.SuccessResult
import coil3.request.allowHardware
import coil3.toBitmap
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private enum class Panel { Subtitles, Audio, Chapters, Settings, Speed, SubtitleDelay, AudioDelay, Style, Fit, Engine, Search }


/**
 * Lecteur TV, pensé pour la télécommande (à la manière de l'Apple TV) :
 * - commandes masquées : OK = pause/lecture, ◀ ▶ = ∓10 s (maintenu : plus vite), ▲ ▼ = commandes ;
 * - commandes visibles : titre, barre de progression (▲ pour la sélectionner, ◀ ▶ avec vignettes,
 *   OK pour sauter), rangée de boutons ; Retour masque les commandes, puis quitte ;
 * - panneaux à droite : sous-titres, audio, chapitres, réglages.
 */
@Composable
fun PlayerScreen(itemId: String, fromStart: Boolean, onExit: () -> Unit, onPlayItem: (String) -> Unit, party: Boolean = false, startAtMs: Long? = null) {
    val context = LocalContext.current
    val controller = remember(itemId) { PlayerController(context, itemId, fromStart, party, startAtMs) }
    val ui by controller.state.collectAsState()
    var visible by remember { mutableStateOf(true) }
    var panel by remember { mutableStateOf<Panel?>(null) }
    var scrub by remember { mutableStateOf<Long?>(null) }
    var feedback by remember { mutableStateOf<String?>(null) }
    var hideJob by remember { mutableStateOf<Job?>(null) }
    var repeats by remember { mutableIntStateOf(0) }
    var tabsOpen by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val rootFocus = remember { FocusRequester() }
    val playFocus = remember { FocusRequester() }
    val panelFocus = remember { FocusRequester() }
    val skipFocus = remember { FocusRequester() }

    DisposableEffect(controller) {
        val window = (context as? Activity)?.window
        window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        controller.onPlayNext = { next -> onPlayItem(next) }
        controller.onFinished = onExit
        controller.start()
        app.optifin.tv.WatchParty.playerOpen = true
        onDispose {
            app.optifin.tv.WatchParty.playerOpen = false
            window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            controller.close()
        }
    }

    val engineState by (ui.engine?.state ?: remember { kotlinx.coroutines.flow.MutableStateFlow(EngineState()) }).collectAsState()

    fun scheduleHide() {
        hideJob?.cancel()
        hideJob = scope.launch {
            delay(4500)
            if (panel == null && scrub == null && !tabsOpen && controller.engine?.state?.value?.playing == true) {
                visible = false
                runCatching { rootFocus.requestFocus() }
            }
        }
    }

    fun show(focusPlay: Boolean = false) {
        visible = true
        scheduleHide()
        if (focusPlay) scope.launch {
            delay(30)
            runCatching { playFocus.requestFocus() }
        }
    }

    fun hide() {
        hideJob?.cancel()
        visible = false
        scrub = null
        runCatching { rootFocus.requestFocus() }
    }

    fun seekWithFeedback(delta: Long) {
        controller.seekBy(delta)
        feedback = (if (delta > 0) "+" else "−") + "${kotlin.math.abs(delta) / 1000} s"
        scope.launch {
            val shown = feedback
            delay(1100)
            if (feedback == shown) feedback = null
        }
    }

    fun onBack() {
        when {
            panel != null -> {
                // Sous-menu : retour au menu dont il vient.
                panel = when (panel) {
                    Panel.Speed, Panel.Fit, Panel.Engine -> Panel.Settings
                    Panel.Style, Panel.Search, Panel.SubtitleDelay -> Panel.Subtitles
                    Panel.AudioDelay -> Panel.Audio
                    else -> null
                }
                if (panel == null) show(focusPlay = true)
            }
            scrub != null -> scrub = null
            visible && ui.phase == PlayerPhase.Playing -> hide()
            else -> onExit()
        }
    }

    BackHandler(onBack = ::onBack)

    // Commandes affichées au démarrage, masquées après la première image.
    LaunchedEffect(engineState.ready) {
        if (engineState.ready) {
            show(focusPlay = true)
        }
    }
    LaunchedEffect(Unit) { runCatching { rootFocus.requestFocus() } }

    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black)
            .focusRequester(rootFocus)
            .onPreviewKeyEvent { e ->
                // Traité ici : sinon Compose rend d'abord le focus à cette zone (focusable) et « mange » la touche,
                // il fallait deux appuis et le panneau restait ouvert sans focus.
                if (e.key == Key.Back) {
                    if (e.type == KeyEventType.KeyDown && e.nativeKeyEvent.repeatCount == 0) onBack()
                    return@onPreviewKeyEvent true
                }
                if (e.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                val repeat = e.nativeKeyEvent.repeatCount > 0
                when (e.key) {
                    Key.MediaPlayPause, Key.MediaPlay, Key.MediaPause -> {
                        if (!repeat) controller.togglePlay()
                        show(focusPlay = !visible)
                        return@onPreviewKeyEvent true
                    }
                    Key.MediaFastForward -> { seekWithFeedback(30_000); return@onPreviewKeyEvent true }
                    Key.MediaRewind -> { seekWithFeedback(-30_000); return@onPreviewKeyEvent true }
                    Key.MediaNext -> { controller.playNext(); return@onPreviewKeyEvent true }
                }
                if (ui.phase != PlayerPhase.Playing) return@onPreviewKeyEvent false
                // Fenêtre ouverte : ◀ ▶ ne doivent pas faire sortir le focus de la liste (la recherche garde son champ de saisie).
                if (panel != null && panel != Panel.Search && (e.key == Key.DirectionLeft || e.key == Key.DirectionRight)) return@onPreviewKeyEvent true
                if (!visible && panel == null) {
                    when (e.key) {
                        Key.DirectionCenter, Key.Enter, Key.NumPadEnter -> {
                            if (!repeat) when {
                                ui.upNext && ui.extras.nextEpisode != null -> controller.playNext()
                                ui.segment != null -> controller.skipSegment()
                                else -> {
                                    controller.togglePlay()
                                    show(focusPlay = true)
                                }
                            }
                            true
                        }
                        Key.DirectionLeft, Key.DirectionRight -> {
                            repeats = if (repeat) repeats + 1 else 0
                            val step = when { repeats > 20 -> 120_000L; repeats > 6 -> 60_000L; repeats > 0 -> 30_000L; else -> 10_000L }
                            seekWithFeedback(if (e.key == Key.DirectionRight) step else -step)
                            true
                        }
                        Key.DirectionUp, Key.DirectionDown -> {
                            show(focusPlay = true)
                            true
                        }
                        else -> false
                    }
                } else {
                    if (panel == null) scheduleHide()
                    false
                }
            }
            // Commandes affichées : cette zone ne doit plus être une cible, sinon une flèche au bord des commandes y envoyait le focus.
            .focusProperties { canFocus = !(visible && engineState.ready && ui.phase == PlayerPhase.Playing) }
            .focusable(),
    ) {
        ui.engine?.View(Modifier.fillMaxSize())

        when (ui.phase) {
            PlayerPhase.Preparing -> Preparing(ui)
            PlayerPhase.Error -> ErrorView(ui, onRetry = controller::retry, onBack = onExit)
            else -> {}
        }
        if (ui.phase == PlayerPhase.Playing && !engineState.ready) Preparing(ui)

        // Saut : indication discrète du côté du saut.
        feedback?.let {
            val forward = it.startsWith("+")
            Row(
                Modifier.align(if (forward) Alignment.CenterEnd else Alignment.CenterStart).padding(horizontal = 72.dp)
                    .clip(RoundedCornerShape(30.dp)).background(Color(0x80000000)).padding(horizontal = 18.dp, vertical = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(if (forward) Icons.Rounded.Forward10 else Icons.Rounded.Replay10, null, Modifier.size(30.dp))
                Text(it, style = MaterialTheme.typography.titleMedium)
            }
        }
        if (engineState.ready && engineState.buffering && !visible) {
            Spinner(Modifier.align(Alignment.Center))
        }

        if (ui.phase == PlayerPhase.Playing && engineState.ready) {
            AnimatedVisibility(visible, enter = fadeIn(tween(220)), exit = fadeOut(tween(300))) {
                Controls(
                    ui, engineState, controller, scrub, panel,
                    onScrub = { scrub = it; if (it == null) scheduleHide() else hideJob?.cancel() },
                    onPanel = { panel = it; hideJob?.cancel() },
                    onSkip = ::seekWithFeedback,
                    onTabs = { tabsOpen = it; if (it) hideJob?.cancel() else scheduleHide() },
                    barFocus = playFocus,
                )
            }
            // « Passer l'intro » et « Épisode suivant » : visibles même commandes masquées.
            val segment = ui.segment
            if (segment != null && !ui.upNext && panel == null) {
                Box(Modifier.align(Alignment.BottomEnd).padding(end = OF.SafeX, bottom = if (visible) 190.dp else OF.SafeY + 24.dp)) {
                    TvButton(segment.type.skipLabel, controller::skipSegment, Modifier.focusRequester(skipFocus), icon = Icons.Rounded.SkipNext, primary = true)
                }
            }
            val next = ui.extras.nextEpisode
            if (ui.upNext && next != null && panel == null) {
                UpNextCard(next, engineState, Modifier.align(Alignment.BottomEnd).padding(end = OF.SafeX, bottom = if (visible) 190.dp else OF.SafeY + 24.dp),
                    onPlay = controller::playNext, onDismiss = controller::dismissUpNext)
            }
            if (AppServices.settings.value.debugMode) DebugOverlay(ui, Modifier.align(Alignment.TopStart).padding(start = OF.SafeX, top = OF.SafeY))
            ui.party?.let {
                Box(Modifier.align(Alignment.TopEnd).padding(end = OF.SafeX, top = OF.SafeY).clip(RoundedCornerShape(20.dp)).background(Color(0xB31C1C20)).padding(horizontal = 16.dp, vertical = 8.dp)) {
                    Text(it, style = MaterialTheme.typography.labelLarge)
                }
            }
        }

        AnimatedVisibility(
            panel != null, modifier = Modifier.align(Alignment.BottomEnd).padding(end = OF.SafeX, bottom = 150.dp),
            enter = slideInVertically { it / 8 } + fadeIn(tween(160)), exit = fadeOut(tween(120)),
        ) {
            panel?.let { p ->
                SidePanel(p, ui, controller, panelFocus, onNavigate = { panel = it }, onClose = { panel = null; show(focusPlay = true) })
            }
        }
        LaunchedEffect(panel) { if (panel != null) { delay(60); runCatching { panelFocus.requestFocus() } } }
    }
}

@Composable
private fun Spinner(modifier: Modifier = Modifier) {
    val transition = androidx.compose.animation.core.rememberInfiniteTransition(label = "spinner")
    val angle by transition.animateFloat(0f, 360f, androidx.compose.animation.core.infiniteRepeatable(tween(900, easing = androidx.compose.animation.core.LinearEasing)), label = "angle")
    Canvas(modifier.size(56.dp)) {
        drawArc(Color.White, startAngle = angle, sweepAngle = 270f, useCenter = false,
            style = androidx.compose.ui.graphics.drawscope.Stroke(width = 4.dp.toPx(), cap = androidx.compose.ui.graphics.StrokeCap.Round))
    }
}

/** Écran de préparation : fond du titre, logo ou titre, indicateur, annonce (bascule…). */
@Composable
private fun Preparing(ui: PlayerUiState) {
    val images = AppServices.images
    val item = ui.item
    Box(Modifier.fillMaxSize().background(Color.Black)) {
        item?.let { AsyncImage(images?.maybe(it.backdrop, 1280), null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(0.dp))) }
        Box(Modifier.fillMaxSize().background(Color(0xCC000000)))
        Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
            Spinner()
            Spacer(Modifier.height(24.dp))
            Text(item?.let { if (it.kind == MediaKind.Episode) "${it.seriesName ?: ""} · ${it.episodeLabel ?: ""}" else it.name } ?: L.t("Préparation…"),
                style = MaterialTheme.typography.titleLarge, color = OF.TextPrimary)
            ui.notice?.let {
                Spacer(Modifier.height(8.dp))
                Text(it, style = MaterialTheme.typography.bodyMedium, color = OF.TextSecondary)
            }
        }
    }
}

@Composable
private fun ErrorView(ui: PlayerUiState, onRetry: () -> Unit, onBack: () -> Unit) {
    val focus = remember { FocusRequester() }
    Box(Modifier.fillMaxSize().background(Color.Black), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.widthIn(max = 900.dp)) {
            Text(ui.error ?: L.t("Lecture impossible."), style = MaterialTheme.typography.headlineSmall, color = OF.TextPrimary)
            ui.technicalError?.let {
                Spacer(Modifier.height(12.dp))
                Text(it, style = MaterialTheme.typography.bodySmall, color = OF.TextTertiary, maxLines = 8)
            }
            Spacer(Modifier.height(28.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                TvButton(L.t("Réessayer"), onRetry, Modifier.focusRequester(focus), primary = true)
                TvButton(L.t("Retour"), onBack, icon = Icons.AutoMirrored.Rounded.ArrowBack)
            }
        }
    }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
}

/** Commandes posées sur l'image : titre et petites icônes, barre fine, temps, onglets Infos et Chapitres. */
@Composable
private fun Controls(
    ui: PlayerUiState,
    s: EngineState,
    controller: PlayerController,
    scrub: Long?,
    activePanel: Panel?,
    onScrub: (Long?) -> Unit,
    onPanel: (Panel) -> Unit,
    onSkip: (Long) -> Unit,
    onTabs: (Boolean) -> Unit,
    barFocus: FocusRequester,
) {
    val item = ui.item
    val duration = if (s.durationMs > 0) s.durationMs else ui.plan?.runtimeMs ?: 0
    val position = scrub ?: s.positionMs
    val remaining = (duration - position).coerceAtLeast(0)
    val enabled = activePanel == null
    var tab by remember { mutableStateOf<PlayerTab?>(null) }
    val veil by animateColorAsState(if (tab != null) Color(0x99000000) else Color.Transparent, tween(200), label = "voile")
    Box(Modifier.fillMaxSize().background(veil)) {
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(0.55f to Color.Transparent, 1f to Color(0xB3000000))))
        Column(Modifier.align(Alignment.BottomStart).fillMaxWidth().padding(horizontal = OF.SafeX, vertical = OF.SafeY)) {
            Row(Modifier.fillMaxWidth().alpha(if (scrub != null) 0f else 1f), verticalAlignment = Alignment.Bottom) {
                Column(Modifier.weight(1f)) {
                    if (item != null) {
                        val episode = item.kind == MediaKind.Episode
                        if (episode) Text(listOfNotNull(item.episodeLabel, item.name).joinToString(" · "), style = MaterialTheme.typography.titleSmall, color = OF.TextSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(if (episode) item.seriesName ?: item.name else item.name, style = MaterialTheme.typography.headlineMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                    ui.extras.nextEpisode?.let { GlyphButton(Icons.Rounded.SkipNext, L.t("Épisode suivant"), controller::playNext, enabled) }
                    GlyphButton(Icons.Outlined.ChatBubbleOutline, L.t("Sous-titres"), { onPanel(Panel.Subtitles) }, enabled, activePanel in SubtitlePanels)
                    if ((ui.plan?.audioTracks?.size ?: 0) > 1) GlyphButton(Icons.Rounded.GraphicEq, L.t("Audio"), { onPanel(Panel.Audio) }, enabled, activePanel in AudioPanels)
                    GlyphButton(Icons.Rounded.Tune, L.t("Réglages"), { onPanel(Panel.Settings) }, enabled, activePanel in SettingsPanels)
                }
            }
            Spacer(Modifier.height(10.dp))
            Scrubber(
                position, duration, s.bufferedMs, remaining, ui, scrub != null, s.playing, enabled, barFocus,
                onScrub = onScrub,
                onCommit = { target, resume ->
                    controller.seekTo(target)
                    if (resume && !s.playing) controller.togglePlay()
                    onScrub(null)
                },
                onToggle = controller::togglePlay,
                onSkip = onSkip,
            )
            // Onglets : le contenu apparaît dessous dès qu'on y arrive, et disparaît en remontant sur la barre.
            // Groupe de focus : sans lui, passer de l'onglet à une carte semblait quitter la zone et refermait le panneau.
            Column(Modifier.onFocusChanged { if (!it.hasFocus && tab != null) { tab = null; onTabs(false) } }.focusGroup()) {
                Row(Modifier.offset(x = (-14).dp), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    val chapters = ui.extras.chapters.size > 1
                    TabButton(L.t("Infos"), enabled, last = !chapters) { tab = PlayerTab.Info; onTabs(true) }
                    if (chapters) TabButton(L.t("Chapitres"), enabled, last = true) { tab = PlayerTab.Chapters; onTabs(true) }
                }
                when (tab) {
                    PlayerTab.Info -> InfoTab(ui, remaining, s.rate)
                    PlayerTab.Chapters -> ChaptersTab(ui, position) { controller.seekTo(it) }
                    null -> {}
                }
            }
        }
    }
}

private enum class PlayerTab { Info, Chapters }

private val SubtitlePanels = setOf(Panel.Subtitles, Panel.Style, Panel.Search, Panel.SubtitleDelay)
private val AudioPanels = setOf(Panel.Audio, Panel.AudioDelay)
private val SettingsPanels = setOf(Panel.Settings, Panel.Speed, Panel.Fit, Panel.Engine)

/** Petite icône sans fond ; disque blanc au focus, et tant que son menu est ouvert. */
@Composable
private fun GlyphButton(icon: ImageVector, label: String, onClick: () -> Unit, enabled: Boolean, active: Boolean = false) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.size(44.dp),
        shape = ButtonDefaults.shape(CircleShape),
        colors = ButtonDefaults.colors(
            containerColor = Color.Transparent, contentColor = Color.White,
            focusedContainerColor = Color.White, focusedContentColor = Color.Black,
            disabledContainerColor = if (active) Color(0xE6FFFFFF) else Color.Transparent,
            disabledContentColor = if (active) Color.Black else Color.White,
        ),
        scale = ButtonDefaults.scale(focusedScale = 1.08f),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp),
    ) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Icon(icon, label, Modifier.size(24.dp)) }
    }
}

/** Onglet : simple texte, pastille blanche au focus. */
@Composable
private fun TabButton(label: String, enabled: Boolean, last: Boolean, onFocused: () -> Unit) {
    Button(
        onClick = onFocused,
        enabled = enabled,
        modifier = Modifier.height(34.dp).onFocusChanged { if (it.isFocused) onFocused() }
            .focusProperties { if (last) right = FocusRequester.Cancel },
        colors = ButtonDefaults.colors(
            containerColor = Color.Transparent, contentColor = Color(0xE6FFFFFF),
            focusedContainerColor = Color.White, focusedContentColor = Color.Black,
            disabledContainerColor = Color.Transparent, disabledContentColor = Color(0xE6FFFFFF),
        ),
        scale = ButtonDefaults.scale(focusedScale = 1.04f),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 14.dp),
    ) {
        Row(Modifier.fillMaxHeight(), verticalAlignment = Alignment.CenterVertically) {
            Text(label, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun InfoTab(ui: PlayerUiState, remaining: Long, rate: Float) {
    val item = ui.item ?: return
    val endsAt = LocalTime.now().plusSeconds((remaining / 1000 / rate.coerceAtLeast(0.25f)).toLong()).format(DateTimeFormatter.ofPattern("H'h'mm"))
    Row(Modifier.padding(top = 14.dp).height(170.dp), horizontalArrangement = Arrangement.spacedBy(20.dp)) {
        AsyncImage(AppServices.images?.maybe(item.poster, 240), null, contentScale = ContentScale.Crop,
            modifier = Modifier.width(113.dp).fillMaxHeight().clip(RoundedCornerShape(10.dp)).background(OF.SurfaceRaised))
        Column(Modifier.widthIn(max = 720.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(item.name, style = MaterialTheme.typography.titleLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text((MediaFormat.metadataLine(item) + L.f("Fin à {0}", endsAt)).joinToString(" · "), style = MaterialTheme.typography.bodySmall, color = OF.TextSecondary, maxLines = 1)
            item.overview?.let { Text(it, style = MaterialTheme.typography.bodyMedium, maxLines = 5, overflow = TextOverflow.Ellipsis) }
        }
    }
}

@Composable
private fun ChaptersTab(ui: PlayerUiState, position: Long, onSeek: (Long) -> Unit) {
    val itemId = ui.plan?.itemId ?: return
    val images = AppServices.images
    val current = ui.extras.chapterAt(position)
    val list = androidx.compose.foundation.lazy.rememberLazyListState(ui.extras.chapters.indexOf(current).coerceAtLeast(0))
    LazyRow(state = list, modifier = Modifier.padding(top = 14.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        items(ui.extras.chapters, key = { it.index }) { c ->
            // Le serveur ne fournit pas toujours d'image de chapitre : sans image, une carte de texte plutôt qu'un rectangle vide.
            val focusedBorder = androidx.tv.material3.Border(androidx.compose.foundation.BorderStroke(3.dp, Color.White), shape = RoundedCornerShape(10.dp))
            val url = c.imageTag?.let { images?.chapter(itemId, c.index, it, 400) }
            Column(Modifier.width(200.dp)) {
                androidx.tv.material3.Surface(
                    onClick = { onSeek(c.startMs) },
                    // Aux deux bouts de la liste, ◀ ▶ restent sur place au lieu de partir vers les onglets ou la barre.
                    modifier = Modifier.focusProperties {
                        if (c == ui.extras.chapters.first()) left = FocusRequester.Cancel
                        if (c == ui.extras.chapters.last()) right = FocusRequester.Cancel
                    },
                    shape = androidx.tv.material3.ClickableSurfaceDefaults.shape(RoundedCornerShape(10.dp)),
                    colors = androidx.tv.material3.ClickableSurfaceDefaults.colors(
                        containerColor = if (url == null) Color(0x33FFFFFF) else OF.SurfaceRaised,
                        focusedContainerColor = if (url == null) Color.White else OF.SurfaceRaised,
                        contentColor = Color.White, focusedContentColor = if (url == null) Color.Black else Color.White,
                    ),
                    scale = androidx.tv.material3.ClickableSurfaceDefaults.scale(focusedScale = 1.05f),
                    border = androidx.tv.material3.ClickableSurfaceDefaults.border(focusedBorder = focusedBorder),
                ) {
                    if (url != null) {
                        AsyncImage(url, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxWidth().height(112.dp))
                    } else {
                        Column(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp)) {
                            Text(c.name, style = MaterialTheme.typography.labelLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Text(MediaFormat.clock(c.startMs), style = MaterialTheme.typography.labelSmall)
                        }
                    }
                }
                if (url != null) {
                    Spacer(Modifier.height(8.dp))
                    Text(c.name, style = MaterialTheme.typography.labelLarge, color = if (c == current) Color.White else OF.TextSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(MediaFormat.clock(c.startMs), style = MaterialTheme.typography.labelSmall, color = OF.TextTertiary)
                }
            }
        }
    }
}

/**
 * Barre de lecture fine. En lecture, ◀ ▶ sautent de 10 s (touche maintenue : défilement avec aperçu). En pause,
 * ◀ ▶ déplacent le curseur et l'aperçu : OK reprend à cette position, Retour annule. Hors défilement, OK = lecture/pause.
 */
@Composable
private fun Scrubber(
    position: Long,
    duration: Long,
    buffered: Long,
    remaining: Long,
    ui: PlayerUiState,
    scrubbing: Boolean,
    playing: Boolean,
    enabled: Boolean,
    focus: FocusRequester,
    onScrub: (Long?) -> Unit,
    onCommit: (Long, Boolean) -> Unit,
    onToggle: () -> Unit,
    onSkip: (Long) -> Unit,
) {
    var focused by remember { mutableStateOf(false) }
    var repeats by remember { mutableIntStateOf(0) }
    var commitJob by remember { mutableStateOf<Job?>(null) }
    val scope = rememberCoroutineScope()
    val fraction = if (duration > 0) (position.toFloat() / duration).coerceIn(0f, 1f) else 0f
    val bufferedFraction = if (duration > 0) (buffered.toFloat() / duration).coerceIn(0f, 1f) else 0f
    BoxWithConstraints(
        Modifier
            .fillMaxWidth()
            .height(50.dp)
            .focusRequester(focus)
            .onFocusChanged {
                focused = it.isFocused
                if (!it.isFocused && scrubbing) onScrub(null)
            }
            .onKeyEvent { e ->
                val left = e.key == Key.DirectionLeft
                val right = e.key == Key.DirectionRight
                val center = e.key == Key.DirectionCenter || e.key == Key.Enter || e.key == Key.NumPadEnter
                val first = e.nativeKeyEvent.repeatCount == 0
                when {
                    center && e.type == KeyEventType.KeyDown -> {
                        commitJob?.cancel()
                        if (first) { if (scrubbing) onCommit(position, true) else onToggle() }
                        true
                    }
                    duration <= 0 -> false
                    (left || right) && e.type == KeyEventType.KeyDown -> {
                        commitJob?.cancel()
                        repeats = if (first) 0 else repeats + 1
                        val delta = if (right) 1 else -1
                        if (playing && !scrubbing && first) {
                            onSkip(delta * 10_000L)
                        } else {
                            val step = when { repeats > 20 -> 120_000L; repeats > 6 -> 60_000L; repeats > 0 -> 30_000L; else -> 10_000L }
                            onScrub((position + delta * step).coerceIn(0, duration))
                        }
                        true
                    }
                    (left || right) && e.type == KeyEventType.KeyUp -> {
                        // Touche maintenue en pleine lecture : saut à la position atteinte. En pause, OK décide.
                        if (playing && scrubbing) commitJob = scope.launch {
                            delay(900)
                            onCommit(position, false)
                        }
                        true
                    }
                    else -> false
                }
            }
            .focusable(enabled),
    ) {
        val width = maxWidth
        val track = if (focused) 8.dp else 6.dp
        Box(Modifier.padding(top = 8.dp).fillMaxWidth().height(track).clip(RoundedCornerShape(4.dp)).background(Color(0x59FFFFFF))) {
            Box(Modifier.fillMaxHeight().fillMaxWidth(bufferedFraction).background(Color(0x40FFFFFF)))
            Box(Modifier.fillMaxHeight().fillMaxWidth(fraction).background(Color.White))
        }
        if (focused) Box(Modifier.offset(x = width * fraction - 1.5.dp, y = 3.dp).width(3.dp).height(18.dp).clip(RoundedCornerShape(2.dp)).background(Color.White))
        // Le temps suit le curseur, calé sur le bord de la barre au tout début et sans jamais toucher le temps restant.
        val timeWidth = 90.dp
        val timeX = width * fraction - timeWidth / 2
        Text(MediaFormat.clock(position), style = MaterialTheme.typography.labelMedium.copy(fontFeatureSettings = "tnum"), color = Color(0xE6FFFFFF),
            textAlign = if (timeX < 0.dp) androidx.compose.ui.text.style.TextAlign.Start else androidx.compose.ui.text.style.TextAlign.Center,
            modifier = Modifier.offset(x = timeX.coerceIn(0.dp, width - timeWidth * 2), y = 26.dp).width(timeWidth))
        Text("−${MediaFormat.clock(remaining)}", style = MaterialTheme.typography.labelMedium.copy(fontFeatureSettings = "tnum"), color = Color(0xE6FFFFFF),
            modifier = Modifier.align(Alignment.TopEnd).offset(y = 26.dp))
        if (scrubbing) {
            val previewWidth = 260.dp
            val x = (width * fraction - previewWidth / 2).coerceIn(0.dp, width - previewWidth)
            Column(Modifier.offset(x = x, y = (-186).dp).width(previewWidth), horizontalAlignment = Alignment.CenterHorizontally) {
                TrickplayPreview(ui, position, previewWidth)
                ui.extras.chapterAt(position)?.let {
                    Spacer(Modifier.height(6.dp))
                    Text(it.name, style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.clip(RoundedCornerShape(8.dp)).background(Color(0xCC000000)).padding(horizontal = 10.dp, vertical = 4.dp))
                }
            }
        }
    }
}

/** Vignette trickplay : découpe de la planche d'images du serveur (chargée avec authentification). */
@Composable
private fun TrickplayPreview(ui: PlayerUiState, position: Long, width: androidx.compose.ui.unit.Dp) {
    val t = ui.extras.trickplay ?: return
    val plan = ui.plan ?: return
    val context = LocalContext.current
    val thumb = (position / t.intervalMs).toInt().coerceIn(0, t.count - 1)
    val tile = thumb / t.perTile
    val bitmap by produceState<Bitmap?>(null, tile) {
        val url = AppServices.images?.trickplayTile(plan.itemId, t.width, tile, plan.mediaSourceId) ?: return@produceState
        val request = ImageRequest.Builder(context).data(url).allowHardware(false)
            .httpHeaders(NetworkHeaders.Builder().set("Authorization", AppServices.client?.authorizationHeader ?: "").build()).build()
        value = (SingletonImageLoader.get(context).execute(request) as? SuccessResult)?.image?.toBitmap()
    }
    val b = bitmap ?: return
    val inTile = thumb % t.perTile
    val col = inTile % t.tileWidth
    val row = inTile / t.tileWidth
    val height = width * (t.height.toFloat() / t.width)
    Canvas(Modifier.width(width).height(height).clip(RoundedCornerShape(10.dp)).border(2.dp, Color.White, RoundedCornerShape(10.dp))) {
        drawImage(
            b.asImageBitmap(),
            srcOffset = IntOffset(col * t.width, row * t.height),
            srcSize = IntSize(t.width, t.height),
            dstSize = IntSize(size.width.toInt(), size.height.toInt()),
        )
    }
}

/** Carte « Épisode suivant » (fin de l'épisode ou générique). */
@Composable
private fun UpNextCard(next: app.optifin.tv.core.media.MediaItem, s: EngineState, modifier: Modifier, onPlay: () -> Unit, onDismiss: () -> Unit) {
    val focus = remember { FocusRequester() }
    val remaining = ((s.durationMs - s.positionMs) / 1000).coerceAtLeast(0)
    AnimatedVisibility(true, enter = slideInVertically { it / 3 } + fadeIn(), exit = slideOutVertically() + fadeOut(), modifier = modifier) {
        Row(
            Modifier.clip(RoundedCornerShape(18.dp)).background(Color(0xF21C1C20)).padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp), verticalAlignment = Alignment.CenterVertically,
        ) {
            AsyncImage(AppServices.images?.maybe(next.landscape, 480), null, contentScale = ContentScale.Crop,
                modifier = Modifier.width(200.dp).height(112.dp).clip(RoundedCornerShape(10.dp)).background(OF.SurfaceRaised))
            Column(Modifier.width(300.dp)) {
                Text(if (remaining in 1..60) L.f("Épisode suivant dans {0} s", remaining) else L.t("Épisode suivant"), style = MaterialTheme.typography.labelLarge, color = OF.TextSecondary)
                Text(listOfNotNull(next.episodeLabel, next.name).joinToString(" · "), style = MaterialTheme.typography.titleMedium, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    TvButton(L.t("Lire"), onPlay, Modifier.focusRequester(focus), icon = Icons.Rounded.PlayArrow, primary = true)
                    TvButton(L.t("Masquer"), onDismiss)
                }
            }
        }
    }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
}

/** Informations de lecture (mode debug) : moteur, décision, flux, décodeur, images perdues. */
@Composable
private fun DebugOverlay(ui: PlayerUiState, modifier: Modifier) {
    val engine = ui.engine ?: return
    val lines by produceState(emptyList<String>(), engine) {
        while (true) {
            val plan = ui.plan
            value = listOfNotNull(
                "Moteur : ${engine.name} · ${ui.decision?.label ?: ""}",
                ui.decision?.reason,
                plan?.let { "Serveur : ${it.method.label} · ${it.container ?: "?"} · ${MediaFormat.bitrate(it.bitrate) ?: "?"}" },
            ) + engine.debugInfo() + (ui.selection?.trace?.take(5) ?: emptyList())
            delay(1000)
        }
    }
    Column(modifier.widthIn(max = 760.dp).clip(RoundedCornerShape(12.dp)).background(Color(0xCC000000)).padding(14.dp)) {
        lines.forEach { Text(it, style = MaterialTheme.typography.bodySmall, color = Color(0xFFB8F5B8), maxLines = 2) }
    }
}

/** Petite fenêtre au-dessus des icônes : pistes et réglages du lecteur. */
@Composable
private fun SidePanel(panel: Panel, ui: PlayerUiState, controller: PlayerController, focus: FocusRequester, onNavigate: (Panel) -> Unit, onClose: () -> Unit) {
    val plan = ui.plan
    val engine = ui.engine
    val settings = AppServices.settings.value
    Column(
        Modifier.width(370.dp).heightIn(max = 480.dp).clip(RoundedCornerShape(22.dp)).background(Color(0xEB2C2C30))
            .padding(horizontal = 8.dp, vertical = 12.dp),
    ) {
        val title = when (panel) {
            Panel.Subtitles -> L.t("Sous-titres")
            Panel.Audio -> L.t("Audio")
            Panel.Chapters -> L.t("Chapitres")
            Panel.Settings -> L.t("Réglages")
            Panel.Speed -> L.t("Vitesse de lecture")
            Panel.SubtitleDelay -> L.t("Décalage des sous-titres")
            Panel.AudioDelay -> L.t("Décalage audio")
            Panel.Style -> L.t("Style des sous-titres")
            Panel.Fit -> L.t("Format de l’image")
            Panel.Engine -> L.t("Lecteur")
            Panel.Search -> L.t("Sous-titres en ligne")
        }
        Text(title.uppercase(), style = MaterialTheme.typography.labelMedium, color = OF.TextSecondary, modifier = Modifier.padding(start = 12.dp, bottom = 8.dp))
        LazyColumn(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            fun check(on: Boolean): (@Composable () -> Unit)? = if (on) { { Icon(Icons.Rounded.Check, null) } } else null
            when (panel) {
                Panel.Subtitles -> {
                    val current = plan?.subtitleIndex
                    item { MenuRow(L.t("Désactivés"), { controller.selectTrack(TrackType.Subtitle, null); onClose() }, if (current == null) Modifier.focusRequester(focus) else Modifier, selected = current == null, trailing = check(current == null)) }
                    items(plan?.subtitleTracks ?: emptyList(), key = { it.index }) { t ->
                        MenuRow(trackLabel(t), { controller.selectTrack(TrackType.Subtitle, t); onClose() },
                            if (t.index == current) Modifier.focusRequester(focus) else Modifier, supporting = trackDetails(t), selected = t.index == current, trailing = check(t.index == current))
                    }
                    item { MenuRow(L.t("Rechercher en ligne…"), { onNavigate(Panel.Search) }, supporting = L.t("Fournisseurs du serveur (OpenSubtitles…)")) }
                    item { MenuRow(L.t("Style des sous-titres"), { onNavigate(Panel.Style) }, supporting = L.f("Taille {0} % · {1}", (settings.subtitleScale * 100).toInt(), settings.subtitleBackground.label)) }
                    if (engine?.capabilities?.subtitleDelay == true) item { MenuRow(L.t("Décalage"), { onNavigate(Panel.SubtitleDelay) }, supporting = delayLabel(ui.subtitleDelayMs)) }
                }
                Panel.Audio -> {
                    val current = plan?.audioIndex
                    items(plan?.audioTracks ?: emptyList(), key = { it.index }) { t ->
                        MenuRow(trackLabel(t), { controller.selectTrack(TrackType.Audio, t); onClose() },
                            if (t.index == current || (current == null && t == plan?.audioTracks?.first())) Modifier.focusRequester(focus) else Modifier,
                            supporting = trackDetails(t), selected = t.index == current, trailing = check(t.index == current))
                    }
                    if (engine?.capabilities?.audioDelay == true) item { MenuRow(L.t("Décalage audio"), { onNavigate(Panel.AudioDelay) }, supporting = delayLabel(ui.audioDelayMs)) }
                }
                Panel.Chapters -> {
                    val position = engine?.state?.value?.positionMs ?: 0
                    val current = ui.extras.chapterAt(position)
                    items(ui.extras.chapters, key = { it.index }) { c ->
                        MenuRow(c.name, { controller.seekTo(c.startMs); onClose() }, if (c == current) Modifier.focusRequester(focus) else Modifier,
                            supporting = MediaFormat.clock(c.startMs), selected = c == current)
                    }
                }
                Panel.Settings -> {
                    item { MenuRow(L.t("Vitesse"), { onNavigate(Panel.Speed) }, Modifier.focusRequester(focus), supporting = "×${engine?.state?.value?.rate ?: 1f}") }
                    item { MenuRow(L.t("Format de l’image"), { onNavigate(Panel.Fit) }, icon = Icons.Rounded.AspectRatio, supporting = ui.fit.label) }
                    item { MenuRow(L.t("Lecteur"), { onNavigate(Panel.Engine) }, supporting = "${engine?.name ?: "?"} · ${ui.decision?.delivery?.label ?: ""}") }
                    item {
                        MenuRow(L.t("Informations de lecture"), {
                            AppServices.settings.update { it.copy(debugMode = !it.debugMode) }
                            onClose()
                        }, icon = Icons.Rounded.Info, trailing = check(settings.debugMode))
                    }
                }
                Panel.Speed -> items(listOf(0.5f, 0.75f, 1f, 1.25f, 1.5f, 1.75f, 2f)) { r ->
                    val current = engine?.state?.value?.rate ?: 1f
                    MenuRow("×$r", { controller.setRate(r); onClose() }, if (r == current) Modifier.focusRequester(focus) else Modifier, selected = r == current, trailing = check(r == current))
                }
                Panel.Fit -> items(VideoFit.entries) { f ->
                    MenuRow(f.label, { controller.setFit(f); onClose() }, if (f == ui.fit) Modifier.focusRequester(focus) else Modifier, selected = f == ui.fit, trailing = check(f == ui.fit))
                }
                Panel.Engine -> items(EngineKind.entries) { k ->
                    val current = ui.decision?.engine == k
                    MenuRow(if (k == EngineKind.Native) L.t("Lecteur natif (Media3)") else "mpv", { if (!current) controller.switchEngine(k); onClose() },
                        if (current) Modifier.focusRequester(focus) else Modifier, selected = current, trailing = check(current),
                        supporting = if (k == EngineKind.Native) L.t("HDR, Dolby Vision, passthrough audio") else L.t("Lit presque tout, sous-titres ASS fidèles"))
                }
                Panel.SubtitleDelay, Panel.AudioDelay -> {
                    val subtitle = panel == Panel.SubtitleDelay
                    val current = if (subtitle) ui.subtitleDelayMs else ui.audioDelayMs
                    items(listOf(-2000L, -1000L, -500L, -250L, -100L, 0L, 100L, 250L, 500L, 1000L, 2000L)) { d ->
                        MenuRow(delayLabel(d), { if (subtitle) controller.setSubtitleDelay(d) else controller.setAudioDelay(d) },
                            if (d == current) Modifier.focusRequester(focus) else Modifier, selected = d == current, trailing = check(d == current))
                    }
                }
                Panel.Style -> {
                    item { Text(L.t("Taille"), style = MaterialTheme.typography.titleSmall, color = OF.TextTertiary, modifier = Modifier.padding(start = 12.dp, top = 6.dp)) }
                    items(listOf(0.8f to L.t("Petite"), 1f to L.t("Normale"), 1.2f to L.t("Grande"), 1.45f to L.t("Très grande"))) { (v, label) ->
                        MenuRow(label, { AppServices.settings.update { it.copy(subtitleScale = v) }; controller.applySubtitleStyle() },
                            if (v == settings.subtitleScale) Modifier.focusRequester(focus) else Modifier, selected = v == settings.subtitleScale, trailing = check(v == settings.subtitleScale))
                    }
                    item { Text(L.t("Style"), style = MaterialTheme.typography.titleSmall, color = OF.TextTertiary, modifier = Modifier.padding(start = 12.dp, top = 12.dp)) }
                    items(SubtitleBackground.entries) { b ->
                        MenuRow(b.label, { AppServices.settings.update { it.copy(subtitleBackground = b) }; controller.applySubtitleStyle() },
                            selected = b == settings.subtitleBackground, trailing = check(b == settings.subtitleBackground))
                    }
                }
                Panel.Search -> item { SubtitleSearch(ui, controller, focus, onClose) }
            }
        }
    }
}

/** Recherche de sous-titres en ligne (fournisseurs du serveur), téléchargement puis sélection. */
@Composable
private fun SubtitleSearch(ui: PlayerUiState, controller: PlayerController, focus: FocusRequester, onClose: () -> Unit) {
    var language by remember { mutableStateOf(AppServices.settings.value.subtitleLanguage ?: "fre") }
    var results by remember { mutableStateOf<List<RemoteSubtitle>?>(null) }
    var message by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val plan = ui.plan ?: return
    LaunchedEffect(language) {
        results = null
        message = null
        try {
            results = AppServices.playback?.searchSubtitles(plan.itemId, language)
            if (results.isNullOrEmpty()) message = L.t("Aucun sous-titre trouvé.")
        } catch (e: Exception) {
            message = e.userMessage()
        }
    }
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        MenuRow(L.f("Langue : {0}", PreferredLanguages[language] ?: language), {
            val keys = PreferredLanguages.keys.toList()
            language = keys[(keys.indexOf(language) + 1) % keys.size]
        }, Modifier.focusRequester(focus), supporting = L.t("OK pour changer"))
        message?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = OF.TextTertiary, modifier = Modifier.padding(12.dp)) }
        if (results == null && message == null) Text("Recherche…", style = MaterialTheme.typography.bodyMedium, color = OF.TextTertiary, modifier = Modifier.padding(12.dp))
        results?.take(25)?.forEach { r ->
            MenuRow(r.name, {
                scope.launch {
                    try {
                        AppServices.playback?.downloadSubtitle(plan.itemId, r.id)
                        AppServices.notice(L.t("Sous-titre téléchargé"))
                        controller.reloadAfterSubtitleDownload()
                        onClose()
                    } catch (e: Exception) {
                        AppServices.notice(e.userMessage())
                    }
                }
            }, supporting = r.details)
        }
    }
}

private fun trackLabel(t: MediaTrack) = t.label + if (t.isForced) L.t(" (forcés)") else ""

private fun trackDetails(t: MediaTrack): String? = listOfNotNull(
    t.codec?.uppercase(), t.channels?.let { "$it can." }, if (t.isExternal) L.t("externe") else null, if (t.isDefault) L.t("par défaut") else null,
).joinToString(" · ").ifEmpty { null }

private fun delayLabel(ms: Long) = when {
    ms == 0L -> L.t("Aucun")
    ms > 0 -> L.f("+{0} ms (plus tard)", ms)
    else -> L.f("{0} ms (plus tôt)", ms)
}
