package app.optifin.tv

import android.content.Context
import android.os.Build
import android.provider.Settings
import app.optifin.tv.core.AppLog
import app.optifin.tv.core.api.ClientIdentity
import app.optifin.tv.core.api.JellyfinClient
import app.optifin.tv.core.auth.AccountStore
import app.optifin.tv.core.auth.ActiveSession
import app.optifin.tv.core.auth.AuthService
import app.optifin.tv.core.auth.KeystoreTokenCipher
import app.optifin.tv.core.auth.TokenCipher
import app.optifin.tv.core.media.HomeRepository
import app.optifin.tv.core.media.ImageUrls
import app.optifin.tv.core.media.MediaRepository
import app.optifin.tv.core.playback.DeviceCapabilities
import app.optifin.tv.core.playback.PlaybackService
import app.optifin.tv.core.settings.SettingsStore
import java.io.File
import java.util.UUID
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/** Services de l'appli (session active et dépôts associés), accessibles partout. */
object AppServices {
    lateinit var context: Context
        private set
    lateinit var identity: ClientIdentity
        private set
    lateinit var accounts: AccountStore
        private set
    lateinit var settings: SettingsStore
        private set
    lateinit var auth: AuthService
        private set

    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    private val _session = MutableStateFlow<ActiveSession?>(null)
    val session: StateFlow<ActiveSession?> = _session

    var client: JellyfinClient? = null
        private set
    var media: MediaRepository? = null
        private set
    var home: HomeRepository? = null
        private set
    var playback: PlaybackService? = null
        private set
    var images: ImageUrls? = null
        private set

    /** Capacités de lecture du téléviseur (sondées une fois). */
    val capabilities: DeviceCapabilities by lazy {
        DeviceCapabilities.probe(context).also { AppLog.i("player", "Capacités : ${it.summary}") }
    }

    /** Contenus modifiés (lecture terminée, vu, favori) : les écrans se rafraîchissent. */
    private val _changes = MutableSharedFlow<String>(extraBufferCapacity = 8)
    val changes: SharedFlow<String> = _changes
    fun notifyChanged(itemId: String = "") {
        _changes.tryEmit(itemId)
    }

    /** Annonces courtes (soirée, mises à jour, erreurs). */
    private val _notices = MutableSharedFlow<String>(extraBufferCapacity = 8)
    val notices: SharedFlow<String> = _notices
    fun notice(text: String) {
        _notices.tryEmit(text)
    }

    val version: String get() = BuildConfig.VERSION_NAME

    fun init(context: Context, cipher: TokenCipher = KeystoreTokenCipher()) {
        this.context = context.applicationContext
        val files = context.filesDir
        AppLog.init(File(files, "logs"))
        settings = SettingsStore(File(files, "settings.json"))
        AppLog.verbose = settings.value.debugMode
        accounts = AccountStore(File(files, "accounts.json"), cipher)
        identity = ClientIdentity("OptiFin TV", deviceName(context), deviceId(context), version)
        auth = AuthService(identity)
        accounts.activeSession()?.let(::activate)
        AppLog.i("app", "Démarrage OptiFin TV $version — ${Build.MANUFACTURER} ${Build.MODEL}, Android ${Build.VERSION.RELEASE} — session ${if (_session.value == null) "aucune" else "restaurée"}")
    }

    /** Ouvre une session (connexion ou bascule de compte). */
    fun signIn(session: ActiveSession) {
        accounts.save(session)
        activate(session)
        AppLog.i("app", "Session : ${session.account.userName} sur ${session.server.name} (Jellyfin ${session.server.version})")
    }

    private fun activate(session: ActiveSession) {
        val client = JellyfinClient(session.server.baseUrl, identity) { session.token }
        client.onUnauthorized = {
            AppLog.w("auth", "Jeton refusé par le serveur : reconnexion nécessaire")
            scope.launch { signOut(revoke = false) }
        }
        this.client = client
        media = MediaRepository(client, session.account.userId)
        home = HomeRepository(media!!, session.account.id, File(context.cacheDir, "home"))
        playback = PlaybackService(client, session.account.userId)
        images = ImageUrls(session.server.baseUrl)
        _session.value = session
        WatchParty.attach(client)
    }

    fun switchTo(accountId: String): Boolean {
        val session = accounts.session(accountId) ?: return false
        accounts.setActive(accountId)
        activate(session)
        return true
    }

    suspend fun signOut(revoke: Boolean = true) {
        val session = _session.value ?: return
        WatchParty.attach(null)
        if (revoke) auth.logout(session)
        accounts.forgetToken(session.account.id)
        client = null
        media = null
        home = null
        playback = null
        images = null
        _session.value = null
    }

    private fun deviceId(context: Context): String {
        val prefs = context.getSharedPreferences("optifin", Context.MODE_PRIVATE)
        return prefs.getString("deviceId", null) ?: UUID.randomUUID().toString().replace("-", "").also {
            prefs.edit().putString("deviceId", it).apply()
        }
    }

    private fun deviceName(context: Context): String =
        runCatching { Settings.Global.getString(context.contentResolver, "device_name") }.getOrNull()?.takeIf { it.isNotBlank() }
            ?: "${Build.MANUFACTURER} ${Build.MODEL}".trim()
}
