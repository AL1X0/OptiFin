package app.optifin.tv.ui.player

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
fun PlayerScreen(itemId: String, fromStart: Boolean, onExit: () -> Unit, onPlayItem: (String) -> Unit) {
    val context = LocalContext.current
    val controller = remember(itemId) { PlayerController(context, itemId, fromStart) }
    val ui by controller.state.collectAsState()
    var visible by remember { mutableStateOf(true) }
    var panel by remember { mutableStateOf<Panel?>(null) }
    var scrub by remember { mutableStateOf<Long?>(null) }
    var feedback by remember { mutableStateOf<String?>(null) }
    var hideJob by remember { mutableStateOf<Job?>(null) }
    var repeats by remember { mutableIntStateOf(0) }
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
        onDispose {
            window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            controller.close()
        }
    }

    val engineState by (ui.engine?.state ?: remember { kotlinx.coroutines.flow.MutableStateFlow(EngineState()) }).collectAsState()

    fun scheduleHide() {
        hideJob?.cancel()
        hideJob = scope.launch {
            delay(4500)
            if (panel == null && scrub == null && controller.engine?.state?.value?.playing == true) {
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
            delay(800)
            if (feedback == shown) feedback = null
        }
    }

    BackHandler {
        when {
            panel != null -> {
                panel = null
                show(focusPlay = true)
            }
            scrub != null -> scrub = null
            visible && ui.phase == PlayerPhase.Playing -> hide()
            else -> onExit()
        }
    }

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
                if (e.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                val repeat = e.nativeKeyEvent.repeatCount > 0
                when (e.key) {
                    Key.MediaPlayPause, Key.MediaPlay, Key.MediaPause -> {
                        if (!repeat) controller.togglePlay()
                        show()
                        return@onPreviewKeyEvent true
                    }
                    Key.MediaFastForward -> { seekWithFeedback(30_000); return@onPreviewKeyEvent true }
                    Key.MediaRewind -> { seekWithFeedback(-30_000); return@onPreviewKeyEvent true }
                    Key.MediaNext -> { controller.playNext(); return@onPreviewKeyEvent true }
                }
                if (ui.phase != PlayerPhase.Playing) return@onPreviewKeyEvent false
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
            .focusable(),
    ) {
        ui.engine?.View(Modifier.fillMaxSize())

        when (ui.phase) {
            PlayerPhase.Preparing -> Preparing(ui)
            PlayerPhase.Error -> ErrorView(ui, onRetry = controller::retry, onBack = onExit)
            else -> {}
        }
        if (ui.phase == PlayerPhase.Playing && !engineState.ready) Preparing(ui)

        feedback?.let {
            Box(Modifier.align(Alignment.Center).clip(RoundedCornerShape(40.dp)).background(Color(0xB3000000)).padding(horizontal = 28.dp, vertical = 14.dp)) {
                Text(it, style = MaterialTheme.typography.headlineMedium)
            }
        }
        if (engineState.ready && engineState.buffering && !visible) {
            Spinner(Modifier.align(Alignment.Center))
        }

        if (ui.phase == PlayerPhase.Playing && engineState.ready) {
            AnimatedVisibility(visible && panel == null, enter = fadeIn(tween(220)), exit = fadeOut(tween(300))) {
                Controls(
                    ui, engineState, controller, scrub,
                    onScrub = { scrub = it; if (it == null) scheduleHide() else hideJob?.cancel() },
                    onPanel = { panel = it; hideJob?.cancel() },
                    playFocus = playFocus,
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
            panel != null, modifier = Modifier.align(Alignment.CenterEnd),
            enter = slideInHorizontally { it / 2 } + fadeIn(), exit = slideOutHorizontally { it / 2 } + fadeOut(),
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
            Text(item?.let { if (it.kind == MediaKind.Episode) "${it.seriesName ?: ""} · ${it.episodeLabel ?: ""}" else it.name } ?: "Préparation…",
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
            Text(ui.error ?: "Lecture impossible.", style = MaterialTheme.typography.headlineSmall, color = OF.TextPrimary)
            ui.technicalError?.let {
                Spacer(Modifier.height(12.dp))
                Text(it, style = MaterialTheme.typography.bodySmall, color = OF.TextTertiary, maxLines = 8)
            }
            Spacer(Modifier.height(28.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                TvButton("Réessayer", onRetry, Modifier.focusRequester(focus), primary = true)
                TvButton("Retour", onBack, icon = Icons.AutoMirrored.Rounded.ArrowBack)
            }
        }
    }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
}

/** Commandes : titre, barre de progression, temps, boutons. */
@Composable
private fun Controls(
    ui: PlayerUiState,
    s: EngineState,
    controller: PlayerController,
    scrub: Long?,
    onScrub: (Long?) -> Unit,
    onPanel: (Panel) -> Unit,
    playFocus: FocusRequester,
) {
    val item = ui.item
    val duration = if (s.durationMs > 0) s.durationMs else ui.plan?.runtimeMs ?: 0
    val position = scrub ?: s.positionMs
    val remaining = (duration - position).coerceAtLeast(0)
    val chapter = ui.extras.chapterAt(position)
    val endsAt = LocalTime.now().plusSeconds((remaining / 1000 / s.rate.coerceAtLeast(0.25f)).toLong()).format(DateTimeFormatter.ofPattern("H'h'mm"))
    Box(Modifier.fillMaxSize()) {
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(0f to Color(0x99000000), 0.2f to Color.Transparent, 0.55f to Color.Transparent, 1f to Color(0xE6000000))))
        Column(Modifier.align(Alignment.BottomStart).fillMaxWidth().padding(horizontal = OF.SafeX, vertical = OF.SafeY)) {
            if (item != null) {
                val episode = item.kind == MediaKind.Episode
                Text(if (episode) item.seriesName ?: item.name else item.name, style = MaterialTheme.typography.headlineMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                if (episode) Text(listOfNotNull(item.episodeLabel, item.name).joinToString(" · "), style = MaterialTheme.typography.bodyLarge, color = OF.TextSecondary, maxLines = 1)
            }
            Spacer(Modifier.height(14.dp))
            Scrubber(position, duration, s.bufferedMs, ui, scrub != null, onScrub = onScrub, onCommit = { controller.seekTo(it); onScrub(null) })
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(MediaFormat.clock(position), style = MaterialTheme.typography.titleSmall.copy(fontFeatureSettings = "tnum"))
                Spacer(Modifier.width(16.dp))
                Text(chapter?.name ?: "", style = MaterialTheme.typography.bodyMedium, color = OF.TextTertiary, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                if (duration > 0) Text("Fin à $endsAt", style = MaterialTheme.typography.bodyMedium, color = OF.TextTertiary)
                Spacer(Modifier.width(20.dp))
                Text("−${MediaFormat.clock(remaining)}", style = MaterialTheme.typography.titleSmall.copy(fontFeatureSettings = "tnum"))
            }
            Spacer(Modifier.height(14.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                ControlButton(Icons.Rounded.Replay10, "−10 s", { controller.seekBy(-10_000) })
                Spacer(Modifier.width(10.dp))
                ControlButton(if (s.playing) Icons.Rounded.Pause else Icons.Rounded.PlayArrow, if (s.playing) "Pause" else "Lecture", controller::togglePlay, Modifier.focusRequester(playFocus))
                Spacer(Modifier.width(10.dp))
                ControlButton(Icons.Rounded.Forward10, "+10 s", { controller.seekBy(10_000) })
                if (ui.extras.nextEpisode != null) {
                    Spacer(Modifier.width(10.dp))
                    ControlButton(Icons.Rounded.SkipNext, "Épisode suivant", controller::playNext)
                }
                Spacer(Modifier.weight(1f))
                ControlButton(Icons.Rounded.ClosedCaption, "Sous-titres", { onPanel(Panel.Subtitles) })
                Spacer(Modifier.width(10.dp))
                if ((ui.plan?.audioTracks?.size ?: 0) > 1) {
                    ControlButton(Icons.Rounded.GraphicEq, "Audio", { onPanel(Panel.Audio) })
                    Spacer(Modifier.width(10.dp))
                }
                if (ui.extras.chapters.size > 1) {
                    ControlButton(Icons.Rounded.List, "Chapitres", { onPanel(Panel.Chapters) })
                    Spacer(Modifier.width(10.dp))
                }
                ControlButton(Icons.Rounded.Tune, "Réglages", { onPanel(Panel.Settings) })
            }
        }
    }
}

/** Bouton du lecteur : icône seule au repos, pilule blanche avec libellé au focus. */
@Composable
private fun ControlButton(icon: ImageVector, label: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    var focused by remember { mutableStateOf(false) }
    Button(
        onClick = onClick,
        modifier = modifier.height(52.dp).onFocusChanged { focused = it.isFocused },
        shape = ButtonDefaults.shape(RoundedCornerShape(26.dp)),
        colors = ButtonDefaults.colors(containerColor = Color(0x29FFFFFF), contentColor = Color.White, focusedContainerColor = Color.White, focusedContentColor = Color.Black),
        scale = ButtonDefaults.scale(focusedScale = 1.05f),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = if (focused) 20.dp else 14.dp),
    ) {
        Icon(icon, label, Modifier.size(28.dp))
        AnimatedVisibility(focused) {
            Text(label, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(start = 10.dp))
        }
    }
}

/**
 * Barre de progression : focalisée (▲ depuis les boutons), ◀ ▶ déplacent un curseur d'aperçu
 * (vignettes trickplay, de plus en plus vite si la touche reste enfoncée), OK ou une courte pause
 * fait sauter la lecture.
 */
@Composable
private fun Scrubber(position: Long, duration: Long, buffered: Long, ui: PlayerUiState, scrubbing: Boolean, onScrub: (Long?) -> Unit, onCommit: (Long) -> Unit) {
    var focused by remember { mutableStateOf(false) }
    var repeats by remember { mutableIntStateOf(0) }
    var commitJob by remember { mutableStateOf<Job?>(null) }
    val scope = rememberCoroutineScope()
    val fraction = if (duration > 0) (position.toFloat() / duration).coerceIn(0f, 1f) else 0f
    val bufferedFraction = if (duration > 0) (buffered.toFloat() / duration).coerceIn(0f, 1f) else 0f
    BoxWithConstraints(
        Modifier
            .fillMaxWidth()
            .height(44.dp)
            .onFocusChanged {
                focused = it.isFocused
                if (!it.isFocused && scrubbing) onScrub(null)
            }
            .onKeyEvent { e ->
                if (duration <= 0) return@onKeyEvent false
                val left = e.key == Key.DirectionLeft
                val right = e.key == Key.DirectionRight
                if (e.type == KeyEventType.KeyDown && (left || right)) {
                    commitJob?.cancel()
                    repeats = if (e.nativeKeyEvent.repeatCount > 0) repeats + 1 else 0
                    val step = when { repeats > 20 -> 120_000L; repeats > 6 -> 60_000L; repeats > 0 -> 30_000L; else -> 10_000L }
                    onScrub((position + if (right) step else -step).coerceIn(0, duration))
                    true
                } else if (e.type == KeyEventType.KeyUp && (left || right)) {
                    commitJob = scope.launch {
                        delay(1100)
                        onCommit(position)
                    }
                    true
                } else if (e.type == KeyEventType.KeyDown && scrubbing && (e.key == Key.DirectionCenter || e.key == Key.Enter)) {
                    commitJob?.cancel()
                    onCommit(position)
                    true
                } else false
            }
            .focusable(),
        contentAlignment = Alignment.CenterStart,
    ) {
        val width = maxWidth
        val thickness = if (focused) 10.dp else 6.dp
        Box(Modifier.fillMaxWidth().height(thickness).clip(RoundedCornerShape(5.dp)).background(Color(0x40FFFFFF))) {
            Box(Modifier.fillMaxHeight().fillMaxWidth(bufferedFraction).background(Color(0x40FFFFFF)))
            Box(Modifier.fillMaxHeight().fillMaxWidth(fraction).background(Color.White))
        }
        if (focused) {
            Box(Modifier.offset(x = width * fraction - 9.dp).size(18.dp).clip(CircleShape).background(Color.White))
        }
        if (scrubbing) {
            val previewWidth = 260.dp
            val x = (width * fraction - previewWidth / 2).coerceIn(0.dp, width - previewWidth)
            Column(Modifier.offset(x = x, y = (-150).dp).width(previewWidth), horizontalAlignment = Alignment.CenterHorizontally) {
                TrickplayPreview(ui, position, previewWidth)
                Spacer(Modifier.height(6.dp))
                Text(MediaFormat.clock(position) + (ui.extras.chapterAt(position)?.let { " · ${it.name}" } ?: ""),
                    style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.clip(RoundedCornerShape(8.dp)).background(Color(0xCC000000)).padding(horizontal = 10.dp, vertical = 4.dp))
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
                Text("Épisode suivant${if (remaining in 1..60) " dans $remaining s" else ""}", style = MaterialTheme.typography.labelLarge, color = OF.TextSecondary)
                Text(listOfNotNull(next.episodeLabel, next.name).joinToString(" · "), style = MaterialTheme.typography.titleMedium, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    TvButton("Lire", onPlay, Modifier.focusRequester(focus), icon = Icons.Rounded.PlayArrow, primary = true)
                    TvButton("Masquer", onDismiss)
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

/** Panneau latéral : listes de pistes, chapitres et réglages du lecteur. */
@Composable
private fun SidePanel(panel: Panel, ui: PlayerUiState, controller: PlayerController, focus: FocusRequester, onNavigate: (Panel) -> Unit, onClose: () -> Unit) {
    val plan = ui.plan
    val engine = ui.engine
    val settings = AppServices.settings.value
    Column(
        Modifier.fillMaxHeight().width(480.dp).background(Brush.horizontalGradient(listOf(Color(0xE6101012), Color(0xFA101012))))
            .padding(horizontal = 24.dp, vertical = OF.SafeY),
    ) {
        val title = when (panel) {
            Panel.Subtitles -> "Sous-titres"
            Panel.Audio -> "Audio"
            Panel.Chapters -> "Chapitres"
            Panel.Settings -> "Réglages"
            Panel.Speed -> "Vitesse de lecture"
            Panel.SubtitleDelay -> "Décalage des sous-titres"
            Panel.AudioDelay -> "Décalage audio"
            Panel.Style -> "Style des sous-titres"
            Panel.Fit -> "Format de l’image"
            Panel.Engine -> "Lecteur"
            Panel.Search -> "Sous-titres en ligne"
        }
        Text(title, style = MaterialTheme.typography.headlineSmall, modifier = Modifier.padding(start = 12.dp, bottom = 14.dp))
        LazyColumn(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            fun check(on: Boolean): (@Composable () -> Unit)? = if (on) { { Icon(Icons.Rounded.Check, null) } } else null
            when (panel) {
                Panel.Subtitles -> {
                    val current = plan?.subtitleIndex
                    item { MenuRow("Désactivés", { controller.selectTrack(TrackType.Subtitle, null); onClose() }, if (current == null) Modifier.focusRequester(focus) else Modifier, selected = current == null, trailing = check(current == null)) }
                    items(plan?.subtitleTracks ?: emptyList(), key = { it.index }) { t ->
                        MenuRow(trackLabel(t), { controller.selectTrack(TrackType.Subtitle, t); onClose() },
                            if (t.index == current) Modifier.focusRequester(focus) else Modifier, supporting = trackDetails(t), selected = t.index == current, trailing = check(t.index == current))
                    }
                    item { MenuRow("Rechercher en ligne…", { onNavigate(Panel.Search) }, supporting = "Fournisseurs du serveur (OpenSubtitles…)") }
                    item { MenuRow("Style des sous-titres", { onNavigate(Panel.Style) }, supporting = "Taille ${(settings.subtitleScale * 100).toInt()} % · ${settings.subtitleBackground.label}") }
                    if (engine?.capabilities?.subtitleDelay == true) item { MenuRow("Décalage", { onNavigate(Panel.SubtitleDelay) }, supporting = delayLabel(ui.subtitleDelayMs)) }
                }
                Panel.Audio -> {
                    val current = plan?.audioIndex
                    items(plan?.audioTracks ?: emptyList(), key = { it.index }) { t ->
                        MenuRow(trackLabel(t), { controller.selectTrack(TrackType.Audio, t); onClose() },
                            if (t.index == current || (current == null && t == plan?.audioTracks?.first())) Modifier.focusRequester(focus) else Modifier,
                            supporting = trackDetails(t), selected = t.index == current, trailing = check(t.index == current))
                    }
                    if (engine?.capabilities?.audioDelay == true) item { MenuRow("Décalage audio", { onNavigate(Panel.AudioDelay) }, supporting = delayLabel(ui.audioDelayMs)) }
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
                    item { MenuRow("Vitesse", { onNavigate(Panel.Speed) }, Modifier.focusRequester(focus), supporting = "×${engine?.state?.value?.rate ?: 1f}") }
                    item { MenuRow("Format de l’image", { onNavigate(Panel.Fit) }, icon = Icons.Rounded.AspectRatio, supporting = ui.fit.label) }
                    item { MenuRow("Lecteur", { onNavigate(Panel.Engine) }, supporting = "${engine?.name ?: "?"} · ${ui.decision?.delivery?.label ?: ""}") }
                    item {
                        MenuRow("Informations de lecture", {
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
                    MenuRow(if (k == EngineKind.Native) "Lecteur natif (Media3)" else "mpv", { if (!current) controller.switchEngine(k); onClose() },
                        if (current) Modifier.focusRequester(focus) else Modifier, selected = current, trailing = check(current),
                        supporting = if (k == EngineKind.Native) "HDR, Dolby Vision, passthrough audio" else "Lit presque tout, sous-titres ASS fidèles")
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
                    item { Text("Taille", style = MaterialTheme.typography.titleSmall, color = OF.TextTertiary, modifier = Modifier.padding(start = 12.dp, top = 6.dp)) }
                    items(listOf(0.8f to "Petite", 1f to "Normale", 1.2f to "Grande", 1.45f to "Très grande")) { (v, label) ->
                        MenuRow(label, { AppServices.settings.update { it.copy(subtitleScale = v) }; controller.applySubtitleStyle() },
                            if (v == settings.subtitleScale) Modifier.focusRequester(focus) else Modifier, selected = v == settings.subtitleScale, trailing = check(v == settings.subtitleScale))
                    }
                    item { Text("Style", style = MaterialTheme.typography.titleSmall, color = OF.TextTertiary, modifier = Modifier.padding(start = 12.dp, top = 12.dp)) }
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
            if (results.isNullOrEmpty()) message = "Aucun sous-titre trouvé."
        } catch (e: Exception) {
            message = e.userMessage()
        }
    }
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        MenuRow("Langue : ${PreferredLanguages[language] ?: language}", {
            val keys = PreferredLanguages.keys.toList()
            language = keys[(keys.indexOf(language) + 1) % keys.size]
        }, Modifier.focusRequester(focus), supporting = "OK pour changer")
        message?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = OF.TextTertiary, modifier = Modifier.padding(12.dp)) }
        if (results == null && message == null) Text("Recherche…", style = MaterialTheme.typography.bodyMedium, color = OF.TextTertiary, modifier = Modifier.padding(12.dp))
        results?.take(25)?.forEach { r ->
            MenuRow(r.name, {
                scope.launch {
                    try {
                        AppServices.playback?.downloadSubtitle(plan.itemId, r.id)
                        AppServices.notice("Sous-titre téléchargé")
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

private fun trackLabel(t: MediaTrack) = t.label + if (t.isForced) " (forcés)" else ""

private fun trackDetails(t: MediaTrack): String? = listOfNotNull(
    t.codec?.uppercase(), t.channels?.let { "$it can." }, if (t.isExternal) "externe" else null, if (t.isDefault) "par défaut" else null,
).joinToString(" · ").ifEmpty { null }

private fun delayLabel(ms: Long) = when {
    ms == 0L -> "Aucun"
    ms > 0 -> "+${ms} ms (plus tard)"
    else -> "${ms} ms (plus tôt)"
}
