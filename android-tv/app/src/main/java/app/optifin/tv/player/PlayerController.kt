package app.optifin.tv.player

import android.content.Context
import app.optifin.tv.AppServices
import app.optifin.tv.core.AppLog
import app.optifin.tv.core.api.userMessage
import app.optifin.tv.core.media.MediaItem
import app.optifin.tv.core.playback.Delivery
import app.optifin.tv.core.playback.EngineDecision
import app.optifin.tv.core.playback.EngineKind
import app.optifin.tv.core.playback.EngineSelection
import app.optifin.tv.core.playback.EngineSelector
import app.optifin.tv.core.playback.MediaSegment
import app.optifin.tv.core.playback.MediaTrack
import app.optifin.tv.core.playback.PlayMethod
import app.optifin.tv.core.playback.PlaybackExtras
import app.optifin.tv.core.playback.PlaybackPlan
import app.optifin.tv.core.playback.PlaybackService
import app.optifin.tv.core.playback.SelectionRequest
import app.optifin.tv.core.playback.TrackType
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

enum class PlayerPhase { Preparing, Playing, Error, Closed }

data class PlayerUiState(
    val phase: PlayerPhase = PlayerPhase.Preparing,
    val item: MediaItem? = null,
    val plan: PlaybackPlan? = null,
    val decision: EngineDecision? = null,
    val selection: EngineSelection? = null,
    val engine: PlaybackEngine? = null,
    val extras: PlaybackExtras = PlaybackExtras.Empty,
    val error: String? = null,
    val technicalError: String? = null,
    val notice: String? = null,
    val segment: MediaSegment? = null,
    val upNext: Boolean = false,
    val subtitleDelayMs: Long = 0,
    val audioDelayMs: Long = 0,
    val fit: VideoFit = VideoFit.Fit,
    val party: String? = null,
)

/**
 * Orchestration d'une lecture, indépendante du moteur : décision de l'EngineSelector, bascule
 * automatique si le moteur échoue avant la première image (autre moteur, puis transcodage),
 * rapports au serveur, pistes, segments, épisode suivant.
 */
class PlayerController(private val context: Context, val itemId: String, private val fromStart: Boolean) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val _state = MutableStateFlow(PlayerUiState())
    val state: StateFlow<PlayerUiState> = _state
    private val failures = mutableListOf<String>()
    private var chain: List<EngineDecision> = emptyList()
    private var attempt = 0
    private var startMs = 0L
    private var reported = false
    private var lastReport = 0L
    private var lastPaused: Boolean? = null
    private var skipped = mutableSetOf<MediaSegment>()
    private var upNextDismissed = false
    private var startupJob: Job? = null
    private var tickJob: Job? = null
    private var closed = false
    private val started = System.currentTimeMillis()

    /** Lecture de l'épisode suivant demandée (écran : navigation). */
    var onPlayNext: ((String) -> Unit)? = null

    /** Fin de lecture (écran : retour). */
    var onFinished: (() -> Unit)? = null

    val engine: PlaybackEngine? get() = _state.value.engine

    fun start() {
        scope.launch { prepare() }
    }

    private fun mark(step: String) = AppLog.i("player", "Démarrage +${System.currentTimeMillis() - started} ms : $step")

    private suspend fun prepare() {
        val media = AppServices.media ?: return
        val playback = AppServices.playback ?: return
        try {
            val item = media.item(itemId)
            _state.value = _state.value.copy(item = item)
            startMs = if (fromStart) 0 else item.resumeMs
            val settings = AppServices.settings.value
            val caps = AppServices.capabilities
            // Sonde : profil mpv (tout en lecture directe) pour connaître la source réelle.
            val probe = playback.prepare(itemId, startMs, EngineDecision(EngineKind.Mpv, Delivery.DirectPlay, reason = "sonde"), caps, settings.effectiveMaxBitrate)
            val (audio, subtitle) = PlaybackService.preferredTracks(probe, settings)
            val selection = EngineSelector.select(SelectionRequest(
                source = probe.source, device = caps, audioIndex = audio, subtitleIndex = subtitle,
                maxBitrate = settings.effectiveMaxBitrate, preference = settings.enginePreference, imageSubtitles = settings.imageSubtitles,
            ))
            selection.trace.forEach { AppLog.i("selector", it) }
            chain = selection.chain
            attempt = 0
            _state.value = _state.value.copy(selection = selection)
            mark("fiche et plan prêts (${selection.primary.label})")
            scope.launch {
                val extras = playback.extras(item, media, probe.mediaSourceId)
                _state.value = _state.value.copy(extras = extras)
                AppLog.i("extras", "${extras.chapters.size} chapitres, trickplay ${if (extras.trickplay != null) "présent" else "absent"}, ${extras.segments.size} segments")
            }
            launch(chain[0], audio, subtitle, probe)
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            fail(e.userMessage(), e.message)
        }
    }

    /** Lance une décision : plan (réutilise la sonde si même profil), moteur, ouverture. */
    private suspend fun launch(decision: EngineDecision, audio: Int?, subtitle: Int?, probe: PlaybackPlan? = null) {
        val playback = AppServices.playback ?: return
        val settings = AppServices.settings.value
        val plan = if (probe != null && decision.engine == EngineKind.Mpv && decision.delivery == Delivery.DirectPlay &&
            probe.audioIndex == audio && probe.subtitleIndex == subtitle) {
            probe
        } else {
            playback.prepare(itemId, startMs, decision, AppServices.capabilities, settings.effectiveMaxBitrate, audio, subtitle, probe?.mediaSourceId ?: _state.value.plan?.mediaSourceId)
        }
        AppLog.i("player", "« ${_state.value.item?.name} » → ${decision.label}${if (attempt > 0) " (repli n° $attempt)" else ""} : ${decision.reason}\n" +
            "  serveur : ${plan.method.label}, conteneur ${plan.container ?: "?"}, vidéo ${plan.videoCodec ?: "?"}, " +
            "débit ${plan.bitrate?.let { "%.1f Mb/s".format(it / 1e6) } ?: "?"}\n" +
            "  audio : ${plan.currentAudio?.label ?: "—"}, sous-titres : ${plan.currentSubtitle?.label ?: "aucun"}")
        val previous = _state.value.engine
        val engine = if (previous != null && previous.name == engineName(decision.engine)) previous else {
            previous?.release()
            if (previous != null) delay(300) // décodeur rendu au système (une seule instance 4K sur bien des TV)
            if (decision.engine == EngineKind.Native) ExoEngine(context) else MpvEngine(context)
        }
        engine.setSubtitleStyle(SubtitleStyle(settings.subtitleScale, settings.subtitleBackground))
        engine.setFit(_state.value.fit)
        _state.value = _state.value.copy(engine = engine, plan = plan, decision = decision, phase = PlayerPhase.Playing, error = null)
        engine.open(mediaFor(plan, startMs))
        if (_state.value.subtitleDelayMs != 0L) engine.setSubtitleDelay(_state.value.subtitleDelayMs)
        if (_state.value.audioDelayMs != 0L) engine.setAudioDelay(_state.value.audioDelayMs)
        mark("moteur ${engine.name} prêt")
        watchStartup(engine)
        startTicks()
    }

    private fun engineName(kind: EngineKind) = if (kind == EngineKind.Native) "Natif" else "mpv"

    /** Média à ouvrir : pistes intégrées par rang, sous-titres texte externes servis par Jellyfin. */
    private fun mediaFor(plan: PlaybackPlan, start: Long): EngineMedia {
        val external = plan.subtitleTracks.filter { (it.isExternal || it.deliveryMethod == "External") && it.isTextBased && it.deliveryUrl != null }
            .map { ExternalSubtitle("ext${it.index}", it.deliveryUrl!!, it.codec, it.language, it.label) }
        val sub = plan.currentSubtitle
        val audio = plan.currentAudio?.let(plan::embeddedOrdinal)
        return EngineMedia(
            url = plan.streamUrl,
            startMs = start,
            authorization = AppServices.client?.authorizationHeader ?: "",
            userAgent = "OptiFin TV/${AppServices.version}",
            audioOrdinal = if (plan.method == PlayMethod.DirectPlay) audio else null,
            subtitleOrdinal = sub?.let(plan::embeddedOrdinal),
            externalSubtitles = external,
            selectedExternal = sub?.let { s -> external.firstOrNull { it.id == "ext${s.index}" }?.id },
            hls = plan.streamUrl.contains(".m3u8"),
        )
    }

    /** Pas d'image dans le délai, ou erreur avant la première image : repli suivant. */
    private fun watchStartup(engine: PlaybackEngine) {
        startupJob?.cancel()
        startupJob = scope.launch {
            val deadline = System.currentTimeMillis() + 25_000
            while (isActive && System.currentTimeMillis() < deadline) {
                val s = engine.state.value
                if (s.ready) {
                    mark("première image")
                    onFirstFrame()
                    return@launch
                }
                if (s.error != null) {
                    startupFailure(s.error)
                    return@launch
                }
                delay(100)
            }
            if (isActive) startupFailure("aucune image après 25 s")
        }
    }

    private suspend fun startupFailure(message: String) {
        val decision = _state.value.decision ?: return
        failures += "${decision.label} : $message"
        AppLog.w("player", "Échec au démarrage — ${decision.label} : $message")
        attempt++
        val next = chain.getOrNull(attempt)
        if (next == null) {
            fail("Le lecteur n’a pas pu lire ce fichier.", failures.joinToString("\n"))
            return
        }
        AppLog.i("player", "Bascule automatique → ${next.label} (${next.reason})")
        _state.value = _state.value.copy(notice = "Bascule vers ${next.label}…")
        val plan = _state.value.plan
        try {
            launch(next, plan?.audioIndex, plan?.subtitleIndex)
        } catch (e: Exception) {
            fail(e.userMessage(), e.message)
        }
    }

    private fun onFirstFrame() {
        _state.value = _state.value.copy(notice = null)
        val plan = _state.value.plan ?: return
        if (!reported) {
            reported = true
            scope.launch { AppServices.playback?.reportStart(plan, startMs) }
        }
    }

    private fun fail(message: String, technical: String?) {
        AppLog.e("player", "Lecture impossible : $message${technical?.let { "\n$it" } ?: ""}")
        _state.value = _state.value.copy(phase = PlayerPhase.Error, error = message, technicalError = technical)
    }

    /** Boucle : position, rapports (10 s, pause), segments, épisode suivant, fin. */
    private fun startTicks() {
        tickJob?.cancel()
        tickJob = scope.launch {
            while (isActive) {
                val engine = _state.value.engine ?: break
                engine.poll()
                val s = engine.state.value
                val plan = _state.value.plan
                if (s.ready && plan != null) {
                    val now = System.currentTimeMillis()
                    val paused = !s.playing
                    if (paused != lastPaused || now - lastReport > 10_000) {
                        lastPaused = paused
                        lastReport = now
                        AppServices.playback?.reportProgress(plan, s.positionMs, paused)
                    }
                    updateSegments(s.positionMs, s.durationMs)
                }
                if (s.ended && s.ready) {
                    onEnded()
                    break
                }
                delay(250)
            }
        }
    }

    private fun updateSegments(position: Long, duration: Long) {
        val extras = _state.value.extras
        val segment = extras.skippableAt(position)?.takeIf { it !in skipped }
        if (segment != null && AppServices.settings.value.autoSkipSegments) {
            skipped += segment
            engine?.seek(segment.endMs)
            AppServices.notice("${segment.type.skipLabel.removePrefix("Passer ").replaceFirstChar { it.uppercase() }} passé")
            return
        }
        val upNextAt = extras.upNextAt(duration)
        val upNext = !upNextDismissed && upNextAt != null && position >= upNextAt
        if (segment != _state.value.segment || upNext != _state.value.upNext) _state.value = _state.value.copy(segment = segment, upNext = upNext)
    }

    private fun onEnded() {
        val next = _state.value.extras.nextEpisode
        if (next != null && AppServices.settings.value.autoPlayNext && !upNextDismissed) playNext() else onFinished?.invoke()
    }

    // ------------------------------------------------------------ Commandes

    fun togglePlay() {
        val e = engine ?: return
        if (e.state.value.playing) e.pause() else e.play()
    }

    fun seekBy(deltaMs: Long) {
        val e = engine ?: return
        val s = e.state.value
        seekTo((s.positionMs + deltaMs).coerceIn(0, maxOf(0, s.durationMs - 1000)))
    }

    fun seekTo(positionMs: Long) {
        engine?.seek(positionMs)
    }

    fun skipSegment() {
        val segment = _state.value.segment ?: return
        skipped += segment
        engine?.seek(segment.endMs)
        _state.value = _state.value.copy(segment = null)
    }

    fun dismissUpNext() {
        upNextDismissed = true
        _state.value = _state.value.copy(upNext = false)
    }

    fun playNext() {
        val next = _state.value.extras.nextEpisode ?: return
        onPlayNext?.invoke(next.id)
    }

    fun setRate(rate: Float) = engine?.setRate(rate)

    fun setFit(fit: VideoFit) {
        engine?.setFit(fit)
        _state.value = _state.value.copy(fit = fit)
    }

    fun setSubtitleDelay(ms: Long) {
        engine?.setSubtitleDelay(ms)
        _state.value = _state.value.copy(subtitleDelayMs = ms)
    }

    fun setAudioDelay(ms: Long) {
        engine?.setAudioDelay(ms)
        _state.value = _state.value.copy(audioDelayMs = ms)
    }

    fun applySubtitleStyle() {
        val s = AppServices.settings.value
        engine?.setSubtitleStyle(SubtitleStyle(s.subtitleScale, s.subtitleBackground))
    }

    /**
     * Changement de piste : lecture directe → changement local par le moteur ; sinon nouveau plan
     * du serveur à la position courante (transcodage avec la nouvelle piste).
     */
    fun selectTrack(type: TrackType, track: MediaTrack?) {
        val plan = _state.value.plan ?: return
        val engine = engine ?: return
        val audio = if (type == TrackType.Audio) track?.index else plan.audioIndex
        val subtitle = if (type == TrackType.Subtitle) track?.index else plan.subtitleIndex
        val local = when {
            type == TrackType.Subtitle && track == null -> true
            plan.method != PlayMethod.DirectPlay -> track?.let { it.type == TrackType.Subtitle && it.isTextBased && it.deliveryUrl != null } == true
            else -> track == null || plan.embeddedOrdinal(track) != null || (track.isTextBased && track.deliveryUrl != null)
        }
        if (local) {
            if (type == TrackType.Audio) engine.selectAudio(track?.let(plan::embeddedOrdinal))
            else engine.selectSubtitle(track?.let(plan::embeddedOrdinal), track?.takeIf { plan.embeddedOrdinal(it) == null }?.let { "ext${it.index}" })
            _state.value = _state.value.copy(plan = plan.copy(audioIndex = audio, subtitleIndex = subtitle))
            return
        }
        val position = engine.state.value.positionMs
        startMs = position
        scope.launch {
            try {
                _state.value = _state.value.copy(notice = "Changement de piste…")
                val decision = _state.value.decision ?: return@launch
                launch(decision, audio, subtitle)
            } catch (e: Exception) {
                AppServices.notice(e.userMessage())
            }
        }
    }

    /** Moteur imposé pour cette lecture (menu Réglages du lecteur). */
    fun switchEngine(kind: EngineKind) {
        val plan = _state.value.plan ?: return
        startMs = engine?.state?.value?.positionMs ?: startMs
        val decision = EngineDecision(kind, if (kind == EngineKind.Mpv) Delivery.DirectPlay else Delivery.DirectPlay, reason = "choisi pendant la lecture")
        scope.launch {
            try {
                _state.value = _state.value.copy(notice = "Bascule vers ${kind.label}…")
                launch(decision, plan.audioIndex, plan.subtitleIndex)
            } catch (e: Exception) {
                AppServices.notice(e.userMessage())
            }
        }
    }

    /** Sous-titre téléchargé sur le serveur : nouveau plan (nouvelle piste sélectionnée), même position. */
    fun reloadAfterSubtitleDownload() {
        val plan = _state.value.plan ?: return
        val decision = _state.value.decision ?: return
        startMs = engine?.state?.value?.positionMs ?: startMs
        scope.launch {
            try {
                val settings = AppServices.settings.value
                val fresh = AppServices.playback?.prepare(itemId, startMs, decision, AppServices.capabilities, settings.effectiveMaxBitrate, plan.audioIndex, null, plan.mediaSourceId) ?: return@launch
                val newest = fresh.subtitleTracks.maxByOrNull { it.index }
                launch(decision, plan.audioIndex, newest?.index)
            } catch (e: Exception) {
                AppServices.notice(e.userMessage())
            }
        }
    }

    fun retry() {
        failures.clear()
        _state.value = PlayerUiState(fit = _state.value.fit)
        start()
    }

    /** Fermeture : rapport « arrêt » envoyé à la position courante, moteur libéré. */
    fun close() {
        if (closed) return
        closed = true
        startupJob?.cancel()
        tickJob?.cancel()
        val engine = _state.value.engine
        val plan = _state.value.plan
        val position = engine?.state?.value?.positionMs ?: 0
        engine?.pause()
        _state.value = _state.value.copy(phase = PlayerPhase.Closed)
        AppServices.scope.launch {
            withContext(NonCancellable) {
                if (plan != null && reported) AppServices.playback?.reportStopped(plan, position)
                engine?.release()
                AppServices.notifyChanged(itemId)
            }
        }
        scope.cancel()
    }
}
