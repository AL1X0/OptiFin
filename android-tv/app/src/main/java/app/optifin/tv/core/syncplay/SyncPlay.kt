package app.optifin.tv.core.syncplay

import app.optifin.tv.core.AppLog
import app.optifin.tv.core.api.JellyfinClient
import java.time.Duration
import java.time.Instant
import kotlin.math.abs
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.longOrNull
import kotlinx.serialization.json.put
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener

/** État d'une soirée (groupe SyncPlay). */
enum class GroupState { Idle, Waiting, Paused, Playing }

data class GroupInfo(val id: String, val name: String, val state: GroupState, val participants: List<String>)

enum class SyncCommandKind { Unpause, Pause, Stop, Seek }

/** Ordre du serveur à appliquer à l'heure [whenAt] (heure du serveur). */
data class SyncCommand(val kind: SyncCommandKind, val playlistItemId: String, val whenAt: Instant, val positionMs: Long, val emittedAt: Instant)

data class QueueItem(val itemId: String, val playlistItemId: String)

/** File de lecture partagée : élément en cours et position de départ. */
data class PlayQueue(val reason: String, val items: List<QueueItem>, val playingIndex: Int, val startMs: Long, val isPlaying: Boolean, val lastUpdate: Instant) {
    val current: QueueItem? get() = items.getOrNull(playingIndex)
}

sealed interface SyncPlayMessage
data class GroupJoined(val group: GroupInfo) : SyncPlayMessage
data class GroupLeft(val groupId: String) : SyncPlayMessage
data class UserJoined(val userName: String) : SyncPlayMessage
data class UserLeft(val userName: String) : SyncPlayMessage
data class StateChanged(val state: GroupState, val reason: String) : SyncPlayMessage
data class QueueChanged(val queue: PlayQueue) : SyncPlayMessage
data class CommandReceived(val command: SyncCommand) : SyncPlayMessage
data class SyncPlayError(val kind: String, val userMessage: String) : SyncPlayMessage
data class KeepAliveRequest(val seconds: Int) : SyncPlayMessage

/** Lecture des messages de la connexion temps réel (/socket). */
object SyncPlayParser {
    fun parse(text: String): SyncPlayMessage? = try {
        val root = app.optifin.tv.core.api.JellyfinJson.parseToJsonElement(text).jsonObject
        val data = root["Data"]
        when (root.str("MessageType")) {
            "ForceKeepAlive" -> KeepAliveRequest((data as? JsonPrimitive)?.intOrNull ?: 60)
            "SyncPlayCommand" -> CommandReceived(command(data!!.jsonObject))
            "SyncPlayGroupUpdate" -> groupUpdate(data!!.jsonObject)
            else -> null
        }
    } catch (e: Exception) {
        null
    }

    private fun groupUpdate(update: JsonObject): SyncPlayMessage? {
        val data = update["Data"]
        return when (val type = update.str("Type")) {
            "GroupJoined" -> GroupJoined(group(data!!.jsonObject))
            "GroupLeft" -> GroupLeft((data as? JsonPrimitive)?.contentOrNull ?: update.str("GroupId") ?: "")
            "UserJoined" -> UserJoined((data as? JsonPrimitive)?.contentOrNull ?: "")
            "UserLeft" -> UserLeft((data as? JsonPrimitive)?.contentOrNull ?: "")
            "StateUpdate" -> StateChanged(state(data?.jsonObject?.str("State")), data?.jsonObject?.str("Reason") ?: "")
            "PlayQueue" -> QueueChanged(queue(data!!.jsonObject))
            "NotInGroup" -> SyncPlayError(type, "Vous ne faites plus partie de cette soirée.")
            "GroupDoesNotExist" -> SyncPlayError(type, "Cette soirée n’existe plus.")
            "CreateGroupDenied" -> SyncPlayError(type, "Votre compte n’a pas le droit de créer une soirée (réglage SyncPlay du serveur).")
            "JoinGroupDenied" -> SyncPlayError(type, "Votre compte n’a pas le droit de rejoindre une soirée (réglage SyncPlay du serveur).")
            "LibraryAccessDenied" -> SyncPlayError(type, "Un participant n’a pas accès à ce titre dans ses bibliothèques.")
            else -> null
        }
    }

    fun group(e: JsonObject) = GroupInfo(
        e.str("GroupId") ?: "", e.str("GroupName") ?: "Soirée", state(e.str("State")),
        (e["Participants"] as? JsonArray)?.mapNotNull { (it as? JsonPrimitive)?.contentOrNull?.takeIf { s -> s.isNotEmpty() } } ?: emptyList(),
    )

    fun groups(e: JsonElement): List<GroupInfo> = (e as? JsonArray)?.map { group(it.jsonObject) } ?: emptyList()

    fun command(e: JsonObject) = SyncCommand(
        runCatching { SyncCommandKind.valueOf(e.str("Command") ?: "") }.getOrDefault(SyncCommandKind.Stop),
        e.str("PlaylistItemId") ?: "", time(e, "When"), e.long("PositionTicks") / 10_000, time(e, "EmittedAt"),
    )

    fun queue(e: JsonObject) = PlayQueue(
        e.str("Reason") ?: "",
        (e["Playlist"] as? JsonArray)?.map { QueueItem(it.jsonObject.str("ItemId") ?: "", it.jsonObject.str("PlaylistItemId") ?: "") } ?: emptyList(),
        (e["PlayingItemIndex"] as? JsonPrimitive)?.intOrNull ?: -1,
        e.long("StartPositionTicks") / 10_000,
        (e["IsPlaying"] as? JsonPrimitive)?.booleanOrNull == true,
        time(e, "LastUpdate"),
    )

    private fun state(s: String?) = runCatching { GroupState.valueOf(s ?: "") }.getOrDefault(GroupState.Idle)
    private fun JsonObject.str(name: String) = (this[name] as? JsonPrimitive)?.takeIf { it.isString }?.content
    private fun JsonObject.long(name: String) = (this[name] as? JsonPrimitive)?.longOrNull ?: 0
    fun time(e: JsonObject, name: String): Instant = e.str(name)?.let { runCatching { Instant.parse(it) }.getOrNull() } ?: Instant.now()
}

/** Horloge du serveur (comme NTP) : échantillon au plus court aller-retour parmi les derniers. */
class TimeSync(private val now: () -> Instant = { Instant.now() }) {
    private val samples = ArrayDeque<Pair<Duration, Duration>>()

    /** Heure du serveur moins heure locale. */
    @Volatile var offset: Duration = Duration.ZERO
        private set
    @Volatile var roundTrip: Duration = Duration.ZERO
        private set

    @Synchronized
    fun addSample(t0: Instant, t1: Instant, t2: Instant, t3: Instant) {
        val off = Duration.between(t0, t1).plus(Duration.between(t3, t2)).dividedBy(2)
        var delay = Duration.between(t0, t3).minus(Duration.between(t1, t2))
        if (delay.isNegative) delay = Duration.ZERO
        samples.addLast(off to delay)
        if (samples.size > 8) samples.removeFirst()
        val best = samples.minBy { it.second }
        offset = best.first
        roundTrip = best.second
    }

    val serverNow: Instant get() = now().plus(offset)
    val localNow: Instant get() = now()
    fun toLocal(server: Instant): Instant = server.minus(offset)
}

/**
 * Soirées : connexion temps réel (/socket, jeton dans l'en-tête, jamais dans l'URL), maintien et
 * reconnexion, horloge du serveur, requêtes du groupe.
 */
class SyncPlayClient(private val api: JellyfinClient, val time: TimeSync = TimeSync()) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var socket: WebSocket? = null
    private var loop: Job? = null
    @Volatile private var keepAliveSeconds = 30

    private val _group = MutableStateFlow<GroupInfo?>(null)
    val group: StateFlow<GroupInfo?> = _group
    private val _connected = MutableStateFlow(false)
    val connected: StateFlow<Boolean> = _connected
    private val _messages = MutableSharedFlow<SyncPlayMessage>(extraBufferCapacity = 64)
    val messages: SharedFlow<SyncPlayMessage> = _messages

    fun start() {
        if (loop != null) return
        loop = scope.launch {
            var backoff = 2_000L
            while (isActive) {
                val closed = kotlinx.coroutines.CompletableDeferred<Unit>()
                val url = api.resolve("socket").toString().replaceFirst("http", "ws")
                val request = Request.Builder().url(url).header("Authorization", api.authorizationHeader).build()
                socket = JellyfinClient.http.newWebSocket(request, object : WebSocketListener() {
                    override fun onOpen(webSocket: WebSocket, response: Response) {
                        _connected.value = true
                        backoff = 2_000L
                        AppLog.i("syncplay", "Connexion temps réel établie")
                        scope.launch { runCatching { syncTime() } }
                    }

                    override fun onMessage(webSocket: WebSocket, text: String) = handle(text)

                    override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                        closed.complete(Unit)
                    }

                    override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                        AppLog.d("syncplay", "Connexion temps réel interrompue : ${t.message}")
                        closed.complete(Unit)
                    }
                })
                val keepAlive = launch {
                    while (isActive) {
                        delay(keepAliveSeconds * 1000L)
                        socket?.send("{\"MessageType\":\"KeepAlive\"}")
                    }
                }
                closed.await()
                keepAlive.cancel()
                socket = null
                _connected.value = false
                delay(backoff)
                backoff = minOf(30_000L, backoff * 2)
            }
        }
    }

    private fun handle(text: String) {
        val msg = SyncPlayParser.parse(text) ?: return
        when (msg) {
            is KeepAliveRequest -> {
                keepAliveSeconds = (msg.seconds / 2).coerceIn(5, 60)
                return
            }
            is GroupJoined -> _group.value = msg.group
            is GroupLeft -> _group.value = null
            is UserJoined -> _group.value?.let { g -> if (msg.userName !in g.participants) _group.value = g.copy(participants = g.participants + msg.userName) }
            is UserLeft -> _group.value?.let { g -> _group.value = g.copy(participants = g.participants - msg.userName) }
            is StateChanged -> _group.value?.let { g -> _group.value = g.copy(state = msg.state) }
            is SyncPlayError -> if (msg.kind == "NotInGroup" || msg.kind == "GroupDoesNotExist") _group.value = null
            else -> {}
        }
        AppLog.d("syncplay", msg.toString())
        _messages.tryEmit(msg)
    }

    /** Mesure l'horloge du serveur (plusieurs allers-retours, le plus court gagne). */
    suspend fun syncTime(samples: Int = 4) {
        repeat(samples) { i ->
            val t0 = time.localNow
            val r: JsonObject = api.get("GetUtcTime")
            val t3 = time.localNow
            time.addSample(t0, SyncPlayParser.time(r, "RequestReceptionTime"), SyncPlayParser.time(r, "ResponseTransmissionTime"), t3)
            if (i + 1 < samples) delay(150)
        }
        AppLog.d("syncplay", "Horloge : décalage ${time.offset.toMillis()} ms, aller-retour ${time.roundTrip.toMillis()} ms")
    }

    suspend fun list(): List<GroupInfo> = SyncPlayParser.groups(api.get<JsonElement>("SyncPlay/List"))
    suspend fun create(name: String) = post("SyncPlay/New", buildJsonObject { put("GroupName", name) })
    suspend fun join(groupId: String) = post("SyncPlay/Join", buildJsonObject { put("GroupId", groupId) })
    suspend fun leave() {
        post("SyncPlay/Leave", null)
        _group.value = null
    }

    suspend fun setQueue(itemIds: List<String>, index: Int, startMs: Long) = post("SyncPlay/SetNewQueue", buildJsonObject {
        put("PlayingQueue", buildJsonArray { itemIds.forEach { add(JsonPrimitive(it)) } })
        put("PlayingItemPosition", index)
        put("StartPositionTicks", startMs * 10_000)
    })

    suspend fun pause() = post("SyncPlay/Pause", null)
    suspend fun unpause() = post("SyncPlay/Unpause", null)
    suspend fun stop() = post("SyncPlay/Stop", null)
    suspend fun seek(positionMs: Long) = post("SyncPlay/Seek", buildJsonObject { put("PositionTicks", positionMs * 10_000) })
    suspend fun ready(positionMs: Long, isPlaying: Boolean, playlistItemId: String) = post("SyncPlay/Ready", state(positionMs, isPlaying, playlistItemId))
    suspend fun buffering(positionMs: Long, isPlaying: Boolean, playlistItemId: String) = post("SyncPlay/Buffering", state(positionMs, isPlaying, playlistItemId))

    private fun state(positionMs: Long, isPlaying: Boolean, playlistItemId: String) = buildJsonObject {
        put("When", time.serverNow.toString())
        put("PositionTicks", positionMs * 10_000)
        put("IsPlaying", isPlaying)
        put("PlaylistItemId", playlistItemId)
    }

    private suspend fun post(path: String, body: JsonObject?) = api.postUnit(path, body?.let(JellyfinClient::json))

    fun close() {
        runCatching { socket?.close(1000, null) }
        scope.cancel()
    }
}

/** Lecteur piloté par une soirée. */
interface SyncTarget {
    val positionMs: Long
    val paused: Boolean
    fun play()
    fun pause()
    fun seek(positionMs: Long)
    fun setSpeed(speed: Float)
}

/** Ce que le lecteur envoie au serveur. */
interface SyncRequests {
    suspend fun ready(positionMs: Long, isPlaying: Boolean, playlistItemId: String)
    suspend fun buffering(positionMs: Long, isPlaying: Boolean, playlistItemId: String)
    suspend fun pause()
    suspend fun unpause()
    suspend fun seek(positionMs: Long)
}

/**
 * Synchronise un lecteur avec la soirée : ordres du serveur appliqués à l'heure prévue, « prêt » et
 * mise en tampon signalés, dérive rattrapée (vitesse ±5 % au-delà de 120 ms, saut au-delà de 800 ms).
 * Les actions de l'utilisateur deviennent des demandes au groupe. (Même logique que mobile et PC.)
 */
class SyncPlayPlayback(
    private val target: SyncTarget,
    private val requests: SyncRequests,
    private val time: TimeSync,
    playlistItemId: String,
    private val scope: CoroutineScope,
) {
    companion object {
        const val SKIP_MS = 800L
        const val SPEED_MS = 120L
        const val STALL_MS = 700L
        const val SETTLE_MS = 2000L
    }

    private var playingFrom: Pair<Instant, Long>? = null
    private var pendingUnpause: Instant? = null
    private var speedAdjusted = false
    private var buffering = false
    private var stallSince: Instant? = null
    private var settleUntil: Instant = Instant.EPOCH
    private var waitingForSeek = false
    private var readyAfterSeekPlaying = false

    var playlistItemId: String = playlistItemId
        private set
    var driftMs: Long = 0
        private set
    var waiting: Boolean = true
        private set

    fun loaded(isPlaying: Boolean) {
        scope.launch { runCatching { requests.ready(target.positionMs, isPlaying, playlistItemId) } }
    }

    fun apply(command: SyncCommand) {
        if (command.kind != SyncCommandKind.Stop && command.playlistItemId != playlistItemId) return
        when (command.kind) {
            SyncCommandKind.Unpause -> {
                waiting = false
                playingFrom = command.whenAt to command.positionMs
                val start = time.toLocal(command.whenAt)
                val now = time.localNow
                if (start.isAfter(now)) {
                    target.pause()
                    seekIfFar(command.positionMs, 250)
                    pendingUnpause = start
                } else {
                    seekIfFar(command.positionMs + Duration.between(start, now).toMillis(), 250)
                    target.play()
                    settleUntil = now.plusMillis(SETTLE_MS)
                    pendingUnpause = null
                }
            }
            SyncCommandKind.Pause -> {
                playingFrom = null
                pendingUnpause = null
                resetSpeed()
                target.pause()
                seekIfFar(command.positionMs, 200)
            }
            SyncCommandKind.Seek -> {
                readyAfterSeekPlaying = playingFrom != null || !target.paused
                playingFrom = null
                pendingUnpause = null
                resetSpeed()
                waiting = true
                target.pause()
                target.seek(command.positionMs)
                waitingForSeek = true
            }
            SyncCommandKind.Stop -> {
                playingFrom = null
                pendingUnpause = null
                resetSpeed()
                target.pause()
            }
        }
    }

    fun onSeekCompleted() {
        if (!waitingForSeek) return
        waitingForSeek = false
        scope.launch { runCatching { requests.ready(target.positionMs, readyAfterSeekPlaying, playlistItemId) } }
    }

    fun onBuffering(stalled: Boolean) {
        if (stalled) {
            if (stallSince == null) stallSince = time.localNow
            return
        }
        stallSince = null
        if (!buffering) return
        buffering = false
        settleUntil = time.localNow.plusMillis(SETTLE_MS)
        scope.launch { runCatching { requests.ready(target.positionMs, playingFrom != null, playlistItemId) } }
    }

    /** ≈ 4 fois par seconde : départ programmé et rattrapage de dérive. */
    fun tick() {
        val now = time.localNow
        val since = stallSince
        if (since != null && !buffering && Duration.between(since, now).toMillis() >= STALL_MS) {
            buffering = true
            scope.launch { runCatching { requests.buffering(target.positionMs, playingFrom != null, playlistItemId) } }
        }
        val at = pendingUnpause
        if (at != null && !now.isBefore(at)) {
            pendingUnpause = null
            target.play()
            settleUntil = now.plusMillis(SETTLE_MS)
            return
        }
        val from = playingFrom ?: return
        if (buffering || target.paused || pendingUnpause != null || now.isBefore(settleUntil)) return
        val expected = from.second + Duration.between(from.first, time.serverNow).toMillis()
        driftMs = target.positionMs - expected
        val gap = abs(driftMs)
        when {
            gap > SKIP_MS -> {
                resetSpeed()
                target.seek(expected)
                settleUntil = now.plusMillis(SETTLE_MS)
            }
            gap > SPEED_MS -> {
                target.setSpeed(if (driftMs > 0) 0.95f else 1.05f)
                speedAdjusted = true
            }
            speedAdjusted && gap < 40 -> resetSpeed()
        }
    }

    private fun resetSpeed() {
        if (!speedAdjusted) return
        speedAdjusted = false
        target.setSpeed(1f)
    }

    private fun seekIfFar(positionMs: Long, tolerance: Long) {
        if (abs(target.positionMs - positionMs) > tolerance) target.seek(positionMs)
    }

    suspend fun requestTogglePlay() = if (playingFrom != null || pendingUnpause != null) requests.pause() else requests.unpause()
    suspend fun requestSeek(positionMs: Long) = requests.seek(positionMs)

    fun onGroupState(state: GroupState) {
        waiting = state == GroupState.Waiting
    }

    fun changeItem(id: String) {
        playlistItemId = id
        playingFrom = null
        pendingUnpause = null
        waiting = true
        resetSpeed()
    }
}

