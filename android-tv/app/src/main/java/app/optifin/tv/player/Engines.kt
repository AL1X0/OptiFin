package app.optifin.tv.player

import android.content.Context
import android.graphics.Color as AndroidColor
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.annotation.OptIn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.C
import androidx.media3.common.MediaItem as ExoMediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.VideoSize
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.CaptionStyleCompat
import androidx.media3.ui.PlayerView
import androidx.media3.ui.SubtitleView
import app.optifin.tv.core.AppLog
import app.optifin.tv.core.settings.SubtitleBackground
import dev.jdtech.mpv.MPVLib
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

enum class VideoFit(val label: String) { Fit("Adapté"), Zoom("Zoom"), Fill("Étiré") }

/** Ce qu'un moteur sait faire (menus proposés). */
data class EngineCapabilities(val subtitleDelay: Boolean, val audioDelay: Boolean, val assRendering: Boolean)

/** État observable d'un moteur. */
data class EngineState(
    val positionMs: Long = 0,
    val durationMs: Long = 0,
    val bufferedMs: Long = 0,
    val playing: Boolean = false,
    val buffering: Boolean = true,
    /** Première image affichée. */
    val ready: Boolean = false,
    val ended: Boolean = false,
    val error: String? = null,
    val videoWidth: Int = 0,
    val videoHeight: Int = 0,
    val rate: Float = 1f,
    val droppedFrames: Int = 0,
    val decoder: String? = null,
)

/** Piste externe à ajouter (fichier servi par Jellyfin). */
data class ExternalSubtitle(val id: String, val url: String, val codec: String?, val language: String?, val title: String)

/** Ce que le moteur doit ouvrir. */
data class EngineMedia(
    val url: String,
    val startMs: Long,
    val authorization: String,
    val userAgent: String,
    /** Rang de la piste audio intégrée (0…), null = défaut. */
    val audioOrdinal: Int?,
    /** Rang du sous-titre intégré, null = aucun (sauf [externalSubtitle]). */
    val subtitleOrdinal: Int?,
    val externalSubtitles: List<ExternalSubtitle> = emptyList(),
    /** Identifiant de la piste externe à afficher. */
    val selectedExternal: String? = null,
    val hls: Boolean = false,
)

data class SubtitleStyle(val scale: Float = 1f, val background: SubtitleBackground = SubtitleBackground.None)

/** Moteur de lecture (Media3 ou libmpv), piloté par le contrôleur. */
interface PlaybackEngine {
    val name: String
    val capabilities: EngineCapabilities
    val state: StateFlow<EngineState>
    fun open(media: EngineMedia)
    fun play()
    fun pause()
    fun seek(positionMs: Long)
    fun setRate(rate: Float)
    fun selectAudio(ordinal: Int?)
    fun selectSubtitle(ordinal: Int?, externalId: String? = null)
    fun setSubtitleDelay(ms: Long) {}
    fun setAudioDelay(ms: Long) {}
    fun setSubtitleStyle(style: SubtitleStyle)
    fun setFit(fit: VideoFit)
    fun release()
    /** Informations techniques (panneau de debug). */
    fun debugInfo(): List<String> = emptyList()
    /** Rafraîchit position / mémoire tampon (appelé par le contrôleur). */
    fun poll() {}

    @Composable
    fun View(modifier: Modifier)
}

// ---------------------------------------------------------------- Media3

/** Lecteur natif : ExoPlayer + extension FFmpeg (audio Dolby, DTS, TrueHD…), rendu SurfaceView (HDR). */
@OptIn(UnstableApi::class)
class ExoEngine(context: Context) : PlaybackEngine {
    override val name = "Natif"
    override val capabilities = EngineCapabilities(subtitleDelay = false, audioDelay = false, assRendering = false)
    private val _state = MutableStateFlow(EngineState())
    override val state: StateFlow<EngineState> = _state
    private var style = SubtitleStyle()
    private var fit = VideoFit.Fit
    private var view: PlayerView? = null
    private val httpFactory = DefaultHttpDataSource.Factory().setAllowCrossProtocolRedirects(true).setConnectTimeoutMs(15_000).setReadTimeoutMs(30_000)
    private var externals: List<ExternalSubtitle> = emptyList()

    val player: ExoPlayer = ExoPlayer.Builder(
        context,
        DefaultRenderersFactory(context)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_ON)
            .setEnableDecoderFallback(true),
    )
        .setMediaSourceFactory(DefaultMediaSourceFactory(httpFactory))
        .setAudioAttributes(androidx.media3.common.AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_MOVIE).build(), true)
        .setHandleAudioBecomingNoisy(true)
        .setSeekBackIncrementMs(10_000)
        .setSeekForwardIncrementMs(10_000)
        .build()

    private var pendingAudio: Int? = null
    private var pendingSubtitle: Int? = null
    private var pendingExternal: String? = null
    private var tracksApplied = false

    init {
        player.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                _state.value = _state.value.copy(
                    buffering = state == Player.STATE_BUFFERING,
                    ended = state == Player.STATE_ENDED,
                    durationMs = player.duration.takeIf { it != C.TIME_UNSET } ?: _state.value.durationMs,
                )
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                _state.value = _state.value.copy(playing = player.playWhenReady)
            }

            override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
                _state.value = _state.value.copy(playing = playWhenReady)
            }

            override fun onRenderedFirstFrame() {
                _state.value = _state.value.copy(ready = true)
            }

            override fun onVideoSizeChanged(videoSize: VideoSize) {
                _state.value = _state.value.copy(videoWidth = videoSize.width, videoHeight = videoSize.height)
            }

            override fun onTracksChanged(tracks: Tracks) {
                if (!tracksApplied && !tracks.isEmpty) {
                    tracksApplied = true
                    applyTracks(pendingAudio, pendingSubtitle, pendingExternal)
                }
            }

            override fun onPlayerError(error: PlaybackException) {
                AppLog.w("exo", "Erreur ${error.errorCodeName} : ${error.message} ${error.cause?.message ?: ""}")
                _state.value = _state.value.copy(error = "${error.errorCodeName}${error.cause?.message?.let { " ($it)" } ?: ""}")
            }
        })
    }

    override fun open(media: EngineMedia) {
        httpFactory.setDefaultRequestProperties(mapOf("Authorization" to media.authorization)).setUserAgent(media.userAgent)
        externals = media.externalSubtitles
        pendingAudio = media.audioOrdinal
        pendingSubtitle = media.subtitleOrdinal
        pendingExternal = media.selectedExternal
        tracksApplied = false
        val item = ExoMediaItem.Builder()
            .setUri(media.url)
            .setMimeType(if (media.hls) MimeTypes.APPLICATION_M3U8 else null)
            .setSubtitleConfigurations(media.externalSubtitles.map { s ->
                ExoMediaItem.SubtitleConfiguration.Builder(android.net.Uri.parse(s.url))
                    .setId(s.id)
                    .setMimeType(subtitleMime(s.codec))
                    .setLanguage(s.language)
                    .setLabel(s.title)
                    .build()
            })
            .build()
        _state.value = EngineState()
        player.setMediaItem(item, media.startMs)
        player.prepare()
        player.playWhenReady = true
    }

    private fun subtitleMime(codec: String?): String = when (codec?.lowercase()) {
        "vtt", "webvtt" -> MimeTypes.TEXT_VTT
        "ass", "ssa" -> MimeTypes.TEXT_SSA
        "ttml" -> MimeTypes.APPLICATION_TTML
        else -> MimeTypes.APPLICATION_SUBRIP
    }

    /** Pistes intégrées par rang d'apparition ; sous-titre externe par identifiant. */
    private fun applyTracks(audio: Int?, subtitle: Int?, external: String?) {
        val tracks = player.currentTracks
        val builder = player.trackSelectionParameters.buildUpon()
        val audioGroups = tracks.groups.filter { it.type == C.TRACK_TYPE_AUDIO }
        if (audio != null) audioGroups.getOrNull(audio)?.let { builder.setOverrideForType(TrackSelectionOverride(it.mediaTrackGroup, 0)) }
        val textGroups = tracks.groups.filter { it.type == C.TRACK_TYPE_TEXT }
        val externalGroup = external?.let { id -> textGroups.firstOrNull { g -> (0 until g.length).any { g.getTrackFormat(it).id?.endsWith(id) == true } } }
        val embedded = textGroups.filter { g -> (0 until g.length).none { i -> externals.any { e -> g.getTrackFormat(i).id?.endsWith(e.id) == true } } }
        val target = externalGroup ?: subtitle?.let { embedded.getOrNull(it) }
        if (target == null) {
            builder.setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
        } else {
            builder.setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false)
            builder.setOverrideForType(TrackSelectionOverride(target.mediaTrackGroup, 0))
        }
        player.trackSelectionParameters = builder.build()
    }

    override fun play() = player.play()
    override fun pause() = player.pause()
    override fun seek(positionMs: Long) = player.seekTo(positionMs.coerceAtLeast(0))
    override fun setRate(rate: Float) {
        player.setPlaybackSpeed(rate)
        _state.value = _state.value.copy(rate = rate)
    }

    override fun selectAudio(ordinal: Int?) {
        pendingAudio = ordinal
        applyTracks(ordinal, pendingSubtitle, pendingExternal)
    }

    override fun selectSubtitle(ordinal: Int?, externalId: String?) {
        pendingSubtitle = ordinal
        pendingExternal = externalId
        applyTracks(pendingAudio, ordinal, externalId)
    }

    override fun setSubtitleStyle(style: SubtitleStyle) {
        this.style = style
        view?.subtitleView?.let(::applyStyle)
    }

    private fun applyStyle(sv: SubtitleView) {
        val bg = if (style.background == SubtitleBackground.Box) 0x99000000.toInt() else AndroidColor.TRANSPARENT
        val edge = when (style.background) {
            SubtitleBackground.None -> CaptionStyleCompat.EDGE_TYPE_OUTLINE
            SubtitleBackground.Shadow -> CaptionStyleCompat.EDGE_TYPE_DROP_SHADOW
            SubtitleBackground.Box -> CaptionStyleCompat.EDGE_TYPE_NONE
        }
        sv.setStyle(CaptionStyleCompat(AndroidColor.WHITE, bg, AndroidColor.TRANSPARENT, edge, AndroidColor.BLACK, null))
        sv.setFractionalTextSize(SubtitleView.DEFAULT_TEXT_SIZE_FRACTION * 1.15f * style.scale)
        sv.setApplyEmbeddedStyles(true)
        sv.setApplyEmbeddedFontSizes(false)
        sv.setBottomPaddingFraction(0.06f)
    }

    override fun setFit(fit: VideoFit) {
        this.fit = fit
        view?.resizeMode = resize(fit)
    }

    private fun resize(fit: VideoFit) = when (fit) {
        VideoFit.Fit -> AspectRatioFrameLayout.RESIZE_MODE_FIT
        VideoFit.Zoom -> AspectRatioFrameLayout.RESIZE_MODE_ZOOM
        VideoFit.Fill -> AspectRatioFrameLayout.RESIZE_MODE_FILL
    }

    override fun poll() {
        val s = _state.value
        val duration = player.duration.takeIf { it != C.TIME_UNSET } ?: s.durationMs
        val counters = player.videoDecoderCounters
        _state.value = s.copy(
            positionMs = player.currentPosition,
            durationMs = duration,
            bufferedMs = player.bufferedPosition,
            droppedFrames = counters?.droppedBufferCount ?: 0,
        )
    }

    override fun debugInfo(): List<String> {
        val video = player.videoFormat
        val audio = player.audioFormat
        return listOfNotNull(
            video?.let { "Vidéo : ${it.sampleMimeType} ${it.width}×${it.height} ${it.frameRate.takeIf { f -> f > 0 }?.let { f -> "%.3f i/s".format(f) } ?: ""} ${it.codecs ?: ""}" },
            video?.colorInfo?.let { "Couleur : ${it.toLogString()}" },
            audio?.let { "Audio : ${it.sampleMimeType} ${it.channelCount} can. ${it.sampleRate} Hz ${it.codecs ?: ""}" },
            "Décodeur vidéo : ${player.videoDecoderCounters?.let { "${it.renderedOutputBufferCount} images, ${it.droppedBufferCount} perdues" } ?: "?"}",
        )
    }

    override fun release() {
        player.release()
        view = null
    }

    @Composable
    override fun View(modifier: Modifier) {
        AndroidView(
            modifier = modifier,
            factory = { ctx ->
                PlayerView(ctx).apply {
                    useController = false
                    setShutterBackgroundColor(AndroidColor.BLACK)
                    setKeepContentOnPlayerReset(true)
                    isFocusable = false
                    isFocusableInTouchMode = false
                    descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
                    resizeMode = resize(fit)
                    subtitleView?.let(::applyStyle)
                    player = this@ExoEngine.player
                    view = this
                }
            },
        )
    }
}

// ---------------------------------------------------------------- libmpv

/**
 * Lecteur mpv (libmpv d'mpv-android) : rendu OpenGL dans sa propre SurfaceView, comme mpv-android
 * et Kodi ; lit pratiquement tout, sous-titres ASS et PGS fidèles (libass).
 */
class MpvEngine(context: Context) : PlaybackEngine, MPVLib.EventObserver, MPVLib.LogObserver {
    override val name = "mpv"
    override val capabilities = EngineCapabilities(subtitleDelay = true, audioDelay = true, assRendering = true)
    private val _state = MutableStateFlow(EngineState())
    override val state: StateFlow<EngineState> = _state
    private val mpv: MPVLib = MPVLib.create(context.applicationContext)!!
    private var fit = VideoFit.Fit
    private var surfaceAttached = false
    private var pendingMedia: EngineMedia? = null
    private var externals: List<ExternalSubtitle> = emptyList()
    private var started = false
    private var released = false

    init {
        mpv.setOptionString("config", "no")
        mpv.setOptionString("vo", "gpu")
        mpv.setOptionString("gpu-context", "android")
        mpv.setOptionString("opengl-es", "yes")
        mpv.setOptionString("hwdec", "mediacodec-copy")
        mpv.setOptionString("hwdec-codecs", "h264,hevc,mpeg4,mpeg2video,vp8,vp9,av1")
        mpv.setOptionString("ao", "audiotrack,opensles")
        mpv.setOptionString("audio-set-media-role", "yes")
        mpv.setOptionString("tls-verify", "yes")
        mpv.setOptionString("tls-ca-file", "/system/etc/security/cacerts")
        mpv.setOptionString("cache", "yes")
        mpv.setOptionString("demuxer-max-bytes", "${64 * 1024 * 1024}")
        mpv.setOptionString("demuxer-max-back-bytes", "${32 * 1024 * 1024}")
        mpv.setOptionString("demuxer-readahead-secs", "20")
        mpv.setOptionString("keep-open", "yes")
        mpv.setOptionString("idle", "yes")
        mpv.setOptionString("force-window", "no")
        mpv.setOptionString("save-position-on-quit", "no")
        mpv.setOptionString("sub-fonts-dir", "/system/fonts")
        mpv.setOptionString("sub-font", "Roboto")
        mpv.setOptionString("sub-ass-override", "scale")
        mpv.setOptionString("sub-use-margins", "no")
        mpv.setOptionString("sub-scale-with-window", "yes")
        mpv.setOptionString("osd-level", "0")
        mpv.setOptionString("input-default-bindings", "no")
        mpv.setOptionString("msg-level", "all=warn")
        mpv.init()
        mpv.addObserver(this)
        mpv.addLogObserver(this)
        mpv.observeProperty("time-pos", MPV_FORMAT_DOUBLE)
        mpv.observeProperty("duration", MPV_FORMAT_DOUBLE)
        mpv.observeProperty("pause", MPV_FORMAT_FLAG)
        mpv.observeProperty("paused-for-cache", MPV_FORMAT_FLAG)
        mpv.observeProperty("eof-reached", MPV_FORMAT_FLAG)
        mpv.observeProperty("demuxer-cache-time", MPV_FORMAT_DOUBLE)
        mpv.observeProperty("video-params/w", MPV_FORMAT_INT64)
        mpv.observeProperty("video-params/h", MPV_FORMAT_INT64)
        mpv.observeProperty("speed", MPV_FORMAT_DOUBLE)
        mpv.observeProperty("hwdec-current", MPV_FORMAT_STRING)
    }

    override fun open(media: EngineMedia) {
        mpv.setOptionString("http-header-fields", "Authorization: ${media.authorization.replace(",", "\\,")}")
        mpv.setOptionString("user-agent", media.userAgent)
        externals = media.externalSubtitles
        _state.value = EngineState()
        started = false
        if (!surfaceAttached) {
            pendingMedia = media
            return
        }
        load(media)
    }

    private fun load(media: EngineMedia) {
        mpv.setOptionString("start", "%.3f".format(java.util.Locale.ROOT, media.startMs / 1000.0))
        mpv.setOptionString("aid", media.audioOrdinal?.let { "${it + 1}" } ?: "auto")
        mpv.setOptionString("sid", media.subtitleOrdinal?.let { "${it + 1}" } ?: "no")
        mpv.command(arrayOf("loadfile", media.url))
        pendingExternalSelect = media.selectedExternal
    }

    private var pendingExternalSelect: String? = null

    override fun play() = mpv.setPropertyBoolean("pause", false)
    override fun pause() = mpv.setPropertyBoolean("pause", true)
    override fun seek(positionMs: Long) = mpv.command(arrayOf("seek", "%.3f".format(java.util.Locale.ROOT, positionMs.coerceAtLeast(0) / 1000.0), "absolute"))
    override fun setRate(rate: Float) = mpv.setPropertyDouble("speed", rate.toDouble())
    override fun selectAudio(ordinal: Int?) = mpv.setPropertyString("aid", ordinal?.let { "${it + 1}" } ?: "auto")

    override fun selectSubtitle(ordinal: Int?, externalId: String?) {
        val external = externalId?.let { id -> externals.firstOrNull { it.id == id } }
        if (external != null) {
            mpv.command(arrayOf("sub-add", external.url, "select", external.title, external.language ?: ""))
        } else {
            mpv.setPropertyString("sid", ordinal?.let { "${it + 1}" } ?: "no")
        }
    }

    override fun setSubtitleDelay(ms: Long) = mpv.setPropertyDouble("sub-delay", ms / 1000.0)
    override fun setAudioDelay(ms: Long) = mpv.setPropertyDouble("audio-delay", ms / 1000.0)

    override fun setSubtitleStyle(style: SubtitleStyle) {
        mpv.setPropertyDouble("sub-scale", style.scale.toDouble())
        when (style.background) {
            SubtitleBackground.None -> {
                mpv.setPropertyString("sub-border-style", "outline-and-shadow")
                mpv.setPropertyString("sub-shadow-offset", "0")
            }
            SubtitleBackground.Shadow -> {
                mpv.setPropertyString("sub-border-style", "outline-and-shadow")
                mpv.setPropertyString("sub-shadow-offset", "2")
            }
            SubtitleBackground.Box -> {
                mpv.setPropertyString("sub-border-style", "opaque-box")
                mpv.setPropertyString("sub-back-color", "#99000000")
            }
        }
    }

    override fun setFit(fit: VideoFit) {
        this.fit = fit
        when (fit) {
            VideoFit.Fit -> { mpv.setPropertyString("keepaspect", "yes"); mpv.setPropertyDouble("panscan", 0.0) }
            VideoFit.Zoom -> { mpv.setPropertyString("keepaspect", "yes"); mpv.setPropertyDouble("panscan", 1.0) }
            VideoFit.Fill -> { mpv.setPropertyString("keepaspect", "no"); mpv.setPropertyDouble("panscan", 0.0) }
        }
    }

    override fun debugInfo(): List<String> = listOfNotNull(
        "Vidéo : ${mpv.getPropertyString("video-codec") ?: "?"} ${mpv.getPropertyString("video-params/pixelformat") ?: ""} ${mpv.getPropertyString("video-params/gamma") ?: ""}",
        "Décodage : ${mpv.getPropertyString("hwdec-current") ?: "logiciel"} · sortie ${mpv.getPropertyString("current-vo") ?: "?"}",
        "Audio : ${mpv.getPropertyString("audio-codec-name") ?: "?"} ${mpv.getPropertyString("audio-params/channel-count") ?: ""} can. → ${mpv.getPropertyString("current-ao") ?: "?"}",
        "Images perdues : ${mpv.getPropertyInt("frame-drop-count") ?: 0} (sortie), ${mpv.getPropertyInt("decoder-frame-drop-count") ?: 0} (décodeur)",
        "Cache : ${mpv.getPropertyString("demuxer-cache-duration")?.toDoubleOrNull()?.let { "%.0f s".format(it) } ?: "?"}",
    )

    override fun poll() {
        if (released) return
        val dropped = (mpv.getPropertyInt("frame-drop-count") ?: 0) + (mpv.getPropertyInt("decoder-frame-drop-count") ?: 0)
        _state.value = _state.value.copy(droppedFrames = dropped)
    }

    override fun release() {
        if (released) return
        released = true
        mpv.removeObserver(this)
        mpv.removeLogObserver(this)
        runCatching { mpv.command(arrayOf("stop")) }
        if (surfaceAttached) {
            runCatching { mpv.setPropertyString("vo", "null"); mpv.detachSurface() }
            surfaceAttached = false
        }
        runCatching { mpv.destroy() }
    }

    // --- Surface : mpv dessine directement dedans (pas de texture intermédiaire).
    private fun attach(holder: SurfaceHolder, width: Int, height: Int) {
        if (released) return
        if (!surfaceAttached) {
            mpv.attachSurface(holder.surface)
            mpv.setOptionString("force-window", "yes")
            mpv.setPropertyString("vo", "gpu")
            surfaceAttached = true
            AppLog.i("mpv", "Surface vidéo attachée ($width×$height)")
            pendingMedia?.let {
                pendingMedia = null
                load(it)
            }
        }
        mpv.setPropertyString("android-surface-size", "${width}x$height")
    }

    private fun detach() {
        if (!surfaceAttached || released) return
        mpv.setPropertyString("vo", "null")
        mpv.setOptionString("force-window", "no")
        mpv.detachSurface()
        surfaceAttached = false
    }

    @Composable
    override fun View(modifier: Modifier) {
        DisposableEffect(Unit) { onDispose { detach() } }
        AndroidView(
            modifier = modifier,
            factory = { ctx ->
                FrameLayout(ctx).apply {
                    setBackgroundColor(AndroidColor.BLACK)
                    isFocusable = false
                    addView(SurfaceView(ctx).apply {
                        isFocusable = false
                        holder.addCallback(object : SurfaceHolder.Callback {
                            override fun surfaceCreated(holder: SurfaceHolder) {}
                            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) = attach(holder, width, height)
                            override fun surfaceDestroyed(holder: SurfaceHolder) = detach()
                        })
                    }, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
                }
            },
        )
    }

    // --- Événements libmpv (fil de libmpv : simple mise à jour de l'état observable).
    override fun eventProperty(property: String) {}

    override fun eventProperty(property: String, value: Long) {
        when (property) {
            "video-params/w" -> _state.value = _state.value.copy(videoWidth = value.toInt())
            "video-params/h" -> _state.value = _state.value.copy(videoHeight = value.toInt())
        }
    }

    override fun eventProperty(property: String, value: Double) {
        when (property) {
            "time-pos" -> _state.value = _state.value.copy(positionMs = (value * 1000).toLong())
            "duration" -> _state.value = _state.value.copy(durationMs = (value * 1000).toLong())
            "demuxer-cache-time" -> _state.value = _state.value.copy(bufferedMs = (value * 1000).toLong())
            "speed" -> _state.value = _state.value.copy(rate = value.toFloat())
        }
    }

    override fun eventProperty(property: String, value: Boolean) {
        when (property) {
            "pause" -> _state.value = _state.value.copy(playing = !value)
            "paused-for-cache" -> _state.value = _state.value.copy(buffering = value)
            "eof-reached" -> if (value && started) _state.value = _state.value.copy(ended = true)
        }
    }

    override fun eventProperty(property: String, value: String) {
        if (property == "hwdec-current") _state.value = _state.value.copy(decoder = value)
    }

    override fun event(eventId: Int) {
        when (eventId) {
            MPV_EVENT_FILE_LOADED -> {
                pendingExternalSelect?.let { id ->
                    pendingExternalSelect = null
                    selectSubtitle(null, id)
                }
            }
            MPV_EVENT_PLAYBACK_RESTART -> {
                started = true
                _state.value = _state.value.copy(ready = true, buffering = false)
            }
            MPV_EVENT_END_FILE -> if (!started) _state.value = _state.value.copy(error = "mpv n’a pas pu ouvrir ce fichier")
        }
    }

    override fun logMessage(prefix: String, level: Int, text: String) {
        val message = "[$prefix] ${text.trim()}"
        when {
            level <= 20 -> AppLog.e("mpv", message)
            level <= 30 -> AppLog.w("mpv", message)
            else -> AppLog.d("mpv", message)
        }
    }

    private companion object {
        const val MPV_FORMAT_STRING = 1
        const val MPV_FORMAT_FLAG = 3
        const val MPV_FORMAT_INT64 = 4
        const val MPV_FORMAT_DOUBLE = 5
        const val MPV_EVENT_END_FILE = 7
        const val MPV_EVENT_FILE_LOADED = 8
        const val MPV_EVENT_PLAYBACK_RESTART = 21
    }
}
