package app.optifin.optifin_native_player

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.VideoSize
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Un lecteur Media3 (ExoPlayer) piloté depuis Dart.
 *
 * Commandes sur `optifin_native_player/player_<id>`, événements sur
 * `optifin_native_player/events_<id>` : `state`, `error`, `completed`.
 * Les sous-titres sont dessinés par OptiFin : les pistes texte sont désactivées.
 */
@OptIn(UnstableApi::class)
class NativePlayer(
    private val context: Context,
    val id: Int,
    messenger: BinaryMessenger,
    private val onDispose: () -> Unit,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler, Player.Listener {

    private val channel = MethodChannel(messenger, "optifin_native_player/player_$id")
    private val eventChannel = EventChannel(messenger, "optifin_native_player/events_$id")
    private var sink: EventChannel.EventSink? = null
    private val pending = mutableListOf<Map<String, Any?>>()
    private val handler = Handler(Looper.getMainLooper())

    private val player: ExoPlayer
    private var started = false
    private var disposed = false
    private var pendingAudioOrdinal: Int? = null
    private var hasPendingAudio = false
    private var droppedFrames = 0L
    private var resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
    private var views = mutableListOf<PlayerView>()

    private val ticker = object : Runnable {
        override fun run() {
            emitState()
            if (player.isPlaying) handler.postDelayed(this, 250)
        }
    }

    init {
        // Repli sur un autre décodeur si le premier échoue (fréquent en HEVC 10 bits).
        val renderers = DefaultRenderersFactory(context).setEnableDecoderFallback(true)
        // Démarrage rapide : lecture dès 1 s de tampon (2,5 s par défaut), 3 s après une coupure.
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                DefaultLoadControl.DEFAULT_MIN_BUFFER_MS,
                DefaultLoadControl.DEFAULT_MAX_BUFFER_MS,
                1_000,
                3_000,
            )
            .build()
        player = ExoPlayer.Builder(context, renderers)
            .setLoadControl(loadControl)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                    .build(),
                true,
            )
            .setHandleAudioBecomingNoisy(true)
            .build()
        player.trackSelectionParameters = player.trackSelectionParameters.buildUpon()
            .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
            .build()
        player.addListener(this)
        player.addAnalyticsListener(object : AnalyticsListener {
            override fun onDroppedVideoFrames(eventTime: AnalyticsListener.EventTime, count: Int, elapsedMs: Long) {
                droppedFrames += count
            }
        })
        channel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    // ------------------------------------------------------------ Vues

    fun attach(view: PlayerView) {
        views.add(view)
        view.player = player
        view.resizeMode = resizeMode
    }

    fun detach(view: PlayerView) {
        views.remove(view)
        if (view.player === player) view.player = null
    }

    // ------------------------------------------------------------ Événements

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        pending.forEach { events?.success(it) }
        pending.clear()
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    private fun send(event: Map<String, Any?>) {
        if (disposed) return
        val s = sink
        if (s != null) s.success(event) else pending.add(event)
    }

    private fun emitState() {
        val size: VideoSize = player.videoSize
        val duration = player.duration
        val status = when {
            player.playbackState == Player.STATE_ENDED -> "ended"
            started -> "ready"
            else -> "loading"
        }
        send(
            mapOf(
                "event" to "state",
                "status" to status,
                "playing" to player.isPlaying,
                "buffering" to (player.playbackState == Player.STATE_BUFFERING),
                "positionMs" to player.currentPosition,
                "durationMs" to (if (duration == C.TIME_UNSET) 0L else duration),
                "bufferedMs" to player.bufferedPosition,
                "rate" to player.playbackParameters.speed.toDouble(),
                "width" to size.width.toDouble(),
                "height" to size.height.toDouble(),
                "droppedFrames" to droppedFrames,
            ),
        )
    }

    override fun onPlaybackStateChanged(state: Int) {
        when (state) {
            Player.STATE_READY -> started = true
            Player.STATE_ENDED -> {
                emitState()
                send(mapOf("event" to "completed"))
                return
            }
        }
        emitState()
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        handler.removeCallbacks(ticker)
        if (isPlaying) handler.post(ticker) else emitState()
    }

    override fun onVideoSizeChanged(videoSize: VideoSize) = emitState()

    override fun onTracksChanged(tracks: Tracks) {
        if (hasPendingAudio) {
            hasPendingAudio = false
            selectAudio(pendingAudioOrdinal)
        }
    }

    override fun onPlayerError(error: PlaybackException) {
        // Code + cause : indispensable pour diagnostiquer un décodeur absent ou un format refusé.
        val cause = error.cause?.let { " — cause ${it.javaClass.simpleName} : ${it.message}" } ?: ""
        send(
            mapOf(
                "event" to "error",
                "message" to "${error.errorCodeName} : ${error.message}$cause",
                "startup" to !started,
            ),
        )
    }

    // ------------------------------------------------------------ Commandes

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> open(call)
            "play" -> player.play()
            "pause" -> player.pause()
            "seek" -> player.seekTo(call.argument<Number>("positionMs")?.toLong() ?: 0L)
            "setRate" -> player.setPlaybackSpeed(call.argument<Number>("rate")?.toFloat() ?: 1f)
            "selectAudio" -> selectAudio(call.argument<Number>("ordinal")?.toInt())
            "setFit" -> {
                resizeMode = when (call.argument<String>("fit")) {
                    "cover" -> AspectRatioFrameLayout.RESIZE_MODE_ZOOM
                    "fill" -> AspectRatioFrameLayout.RESIZE_MODE_FILL
                    else -> AspectRatioFrameLayout.RESIZE_MODE_FIT
                }
                views.forEach { it.resizeMode = resizeMode }
            }
            "dispose" -> dispose()
            else -> return result.notImplemented()
        }
        result.success(null)
    }

    private fun open(call: MethodCall) {
        val url = call.argument<String>("url") ?: return
        val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
        val startMs = call.argument<Number>("startMs")?.toLong() ?: 0L
        pendingAudioOrdinal = call.argument<Number>("audioOrdinal")?.toInt()
        hasPendingAudio = pendingAudioOrdinal != null
        started = false
        droppedFrames = 0

        // En-têtes (Authorization) envoyés à chaque requête : jamais de token dans l'URL.
        val http = DefaultHttpDataSource.Factory()
            .setDefaultRequestProperties(headers)
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(15_000)
            .setReadTimeoutMs(30_000)
            .setUserAgent("OptiFin")
        val factory = DefaultMediaSourceFactory(DefaultDataSource.Factory(context, http))
        val item = MediaItem.Builder()
            .setUri(url)
            .apply { if (url.contains(".m3u8")) setMimeType(MimeTypes.APPLICATION_M3U8) }
            .build()
        player.setMediaSource(factory.createMediaSource(item), startMs)
        player.playWhenReady = true
        player.prepare()
        emitState()
    }

    private fun selectAudio(ordinal: Int?) {
        val groups = player.currentTracks.groups.filter { it.type == C.TRACK_TYPE_AUDIO }
        if (groups.isEmpty()) {
            // Pistes pas encore connues : appliqué au premier onTracksChanged.
            pendingAudioOrdinal = ordinal
            hasPendingAudio = true
            return
        }
        val params = player.trackSelectionParameters.buildUpon().clearOverridesOfType(C.TRACK_TYPE_AUDIO)
        if (ordinal != null && ordinal in groups.indices) {
            params.setOverrideForType(TrackSelectionOverride(groups[ordinal].mediaTrackGroup, 0))
        }
        player.trackSelectionParameters = params.build()
    }

    fun dispose() {
        if (disposed) return
        handler.removeCallbacks(ticker)
        disposed = true
        views.forEach { if (it.player === player) it.player = null }
        views.clear()
        player.removeListener(this)
        player.release()
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        sink = null
        onDispose()
    }
}
