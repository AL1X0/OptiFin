package app.optifin.tv

import app.optifin.tv.core.AppLog
import app.optifin.tv.core.api.JellyfinClient
import app.optifin.tv.core.api.userMessage
import app.optifin.tv.core.syncplay.CommandReceived
import app.optifin.tv.core.syncplay.GroupInfo
import app.optifin.tv.core.syncplay.GroupJoined
import app.optifin.tv.core.syncplay.GroupLeft
import app.optifin.tv.core.syncplay.GroupState
import app.optifin.tv.core.syncplay.PlayQueue
import app.optifin.tv.core.syncplay.QueueChanged
import app.optifin.tv.core.syncplay.StateChanged
import app.optifin.tv.core.syncplay.SyncCommand
import app.optifin.tv.core.syncplay.SyncCommandKind
import app.optifin.tv.core.syncplay.SyncPlayClient
import app.optifin.tv.core.syncplay.SyncPlayError
import app.optifin.tv.core.syncplay.UserJoined
import app.optifin.tv.core.syncplay.UserLeft
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/** Départ d'une lecture en soirée : élément de la file, position, lecture en cours. */
data class PartyStart(val itemId: String, val playlistItemId: String, val startMs: Long, val isPlaying: Boolean)

/**
 * Soirées (SyncPlay de Jellyfin) à l'échelle de l'appli : connexion ouverte dès qu'un compte est
 * actif, état du groupe, ouverture du lecteur chez tout le monde quand un titre est lancé, hôte qui
 * arrête la lecture pour tous en quittant. Compatible mobile, PC et Jellyfin web.
 */
object WatchParty {
    private var client: SyncPlayClient? = null
    private var jobs = mutableListOf<Job>()
    private val _group = MutableStateFlow<GroupInfo?>(null)
    val group: StateFlow<GroupInfo?> = _group
    private val _connected = MutableStateFlow(false)
    val connected: StateFlow<Boolean> = _connected
    private val _commands = MutableSharedFlow<SyncCommand>(extraBufferCapacity = 32)
    val commands: SharedFlow<SyncCommand> = _commands
    private val _states = MutableSharedFlow<GroupState>(extraBufferCapacity = 16)
    val states: SharedFlow<GroupState> = _states
    private val _queues = MutableSharedFlow<PlayQueue>(extraBufferCapacity = 16)
    val queues: SharedFlow<PlayQueue> = _queues

    /** Lecteur à ouvrir (navigation) quand le groupe lance un titre. */
    private val _open = MutableSharedFlow<PartyStart>(extraBufferCapacity = 4)
    val open: SharedFlow<PartyStart> = _open

    private var openedPlaylistItem: String? = null
    private var pending: PartyStart? = null
    private var creating = false
    private var created = false
    private var launching = false
    private var launched = false
    private var stopping = false

    /** Un lecteur est ouvert (annonce « l'hôte a arrêté » seulement dans ce cas). */
    @Volatile var playerOpen = false

    val inParty: Boolean get() = _group.value != null
    val isHost: Boolean get() = inParty && (created || launched)
    val syncClient: SyncPlayClient? get() = client

    fun attach(api: JellyfinClient?) {
        jobs.forEach { it.cancel() }
        jobs.clear()
        client?.close()
        client = null
        _group.value = null
        _connected.value = false
        openedPlaylistItem = null
        pending = null
        resetHost()
        if (api == null) return
        val c = SyncPlayClient(api)
        client = c
        jobs += AppServices.scope.launch { c.group.collect { _group.value = it } }
        jobs += AppServices.scope.launch { c.connected.collect { _connected.value = it } }
        jobs += AppServices.scope.launch { c.messages.collect(::onMessage) }
        c.start()
    }

    private fun resetHost() {
        creating = false
        created = false
        launching = false
        launched = false
    }

    private fun onMessage(message: app.optifin.tv.core.syncplay.SyncPlayMessage) {
        when (message) {
            is GroupJoined -> {
                created = creating
                creating = false
                AppServices.notice("Vous avez rejoint « ${message.group.name} »")
            }
            is GroupLeft -> {
                openedPlaylistItem = null
                pending = null
                resetHost()
                AppServices.notice("Vous avez quitté la soirée")
            }
            is UserJoined -> AppServices.notice("${message.userName} a rejoint la soirée")
            is UserLeft -> AppServices.notice("${message.userName} a quitté la soirée")
            is SyncPlayError -> AppServices.notice(message.userMessage)
            is StateChanged -> _states.tryEmit(message.state)
            is CommandReceived -> {
                val c = message.command
                if (c.kind == SyncCommandKind.Stop) {
                    openedPlaylistItem = null
                    if (!stopping && c.playlistItemId.replace("0", "").isNotEmpty() && playerOpen) AppServices.notice("L’hôte a arrêté la lecture")
                    stopping = false
                }
                _commands.tryEmit(c)
            }
            is QueueChanged -> onQueue(message.queue)
            else -> {}
        }
    }

    private fun onQueue(queue: PlayQueue) {
        if (queue.reason == "NewPlaylist") {
            launched = launching
            launching = false
        }
        _queues.tryEmit(queue)
        val current = queue.current ?: return
        if (current.playlistItemId == openedPlaylistItem) return
        if (queue.reason !in setOf("NewPlaylist", "SetCurrentItem", "NextItem", "PreviousItem")) return
        openedPlaylistItem = current.playlistItemId
        val start = PartyStart(current.itemId, current.playlistItemId, queue.startMs, queue.isPlaying)
        pending = start
        AppLog.i("syncplay", "Titre lancé par la soirée : ${current.itemId}")
        _open.tryEmit(start)
    }

    /** Synchronisation à utiliser par le lecteur qui ouvre [itemId] (null hors soirée). */
    fun partyFor(itemId: String): PartyStart? = pending?.takeIf { inParty && it.itemId == itemId }

    suspend fun list(): List<GroupInfo> = client?.list() ?: emptyList()

    suspend fun create(name: String) = safe {
        creating = true
        client?.create(name)
    }

    suspend fun join(groupId: String) = safe { client?.join(groupId) }

    suspend fun leave() = safe {
        client?.leave()
        openedPlaylistItem = null
        pending = null
        resetHost()
    }

    /** Lance un titre pour toute la soirée (chacun l'ouvre à cette position). */
    suspend fun play(itemId: String, startMs: Long) = safe {
        AppLog.i("syncplay", "Lancement pour la soirée : $itemId")
        launching = true
        client?.setQueue(listOf(itemId), 0, startMs)
    }

    /** L'hôte quitte le lecteur : arrêt de la lecture pour toute la soirée. */
    suspend fun stopForAll() {
        if (!isHost) return
        AppLog.i("syncplay", "L’hôte quitte la lecture : arrêt pour la soirée")
        stopping = true
        safe { client?.stop() }
    }

    private suspend fun safe(action: suspend () -> Unit) {
        try {
            action()
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            AppLog.w("syncplay", e.message ?: "erreur")
            AppServices.notice(e.userMessage())
        }
    }
}
