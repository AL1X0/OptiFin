package app.optifin.tv.core.auth

import app.optifin.tv.core.api.ApiErrorKind
import app.optifin.tv.core.api.ApiException
import app.optifin.tv.core.api.AuthenticateUserByName
import app.optifin.tv.core.api.AuthenticationResult
import app.optifin.tv.core.api.ClientIdentity
import app.optifin.tv.core.api.DiscoveryResponse
import app.optifin.tv.core.api.JellyfinClient
import app.optifin.tv.core.api.JellyfinJson
import app.optifin.tv.core.api.PublicSystemInfo
import app.optifin.tv.core.api.QuickConnectDto
import app.optifin.tv.core.api.QuickConnectResult
import app.optifin.tv.core.api.UserDto
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.SocketTimeoutException
import java.net.URI
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.booleanOrNull

/** Serveur Jellyfin validé (a répondu à /System/Info/Public). */
@Serializable
data class JellyfinServer(val id: String, val name: String, val baseUrl: String, val version: String)

/** Compte connecté sur un serveur. */
@Serializable
data class Account(val serverId: String, val userId: String, val userName: String, val avatarTag: String? = null) {
    val id: String get() = "$serverId:$userId"
}

/** Utilisateur public listé sur l'écran de connexion. */
data class PublicUser(val id: String, val name: String, val avatarTag: String?, val hasPassword: Boolean)

/** Session active : compte, serveur et jeton (en mémoire ; chiffré sur disque). */
data class ActiveSession(val server: JellyfinServer, val account: Account, val token: String)

/** Serveur annoncé sur le réseau local. */
data class DiscoveredServer(val id: String, val name: String, val address: String)

/** Ticket Quick Connect : code à valider depuis un autre appareil, secret à sonder. */
data class QuickConnectTicket(val code: String, val secret: String)

/** Règles pures autour des adresses et versions de serveur (sans réseau, testées). */
object ServerAddress {
    const val DEFAULT_HTTP_PORT = 8096
    private val schemePattern = Regex("^[a-zA-Z][a-zA-Z0-9+.-]*://")
    private val versionPattern = Regex("""^(\d+)\.(\d+)(?:\.(\d+))?""")

    /**
     * Saisie → URL candidates, dans l'ordre d'essai : avec schéma telle quelle ; sans schéma,
     * https puis http, puis http:8096 si aucun port.
     */
    fun candidates(input: String): List<String> {
        var raw = input.trim()
        if (raw.isEmpty()) return emptyList()
        val hasScheme = schemePattern.containsMatchIn(raw)
        raw = raw.trimEnd('/')
        if (hasScheme) {
            val uri = runCatching { URI(raw) }.getOrNull() ?: return emptyList()
            if (uri.host.isNullOrEmpty() || (uri.scheme != "http" && uri.scheme != "https")) return emptyList()
            return listOf(normalize(uri))
        }
        val https = runCatching { URI("https://$raw") }.getOrNull() ?: return emptyList()
        if (https.host.isNullOrEmpty()) return emptyList()
        val http = URI("http://$raw")
        val result = mutableListOf(normalize(https), normalize(http))
        if (!hasExplicitPort(raw)) {
            result.add(normalize(URI("http", null, http.host, DEFAULT_HTTP_PORT, http.path, null, null)))
        }
        return result
    }

    private fun hasExplicitPort(hostAndPath: String): Boolean {
        val authority = hostAndPath.split('/', limit = 2)[0]
        if (authority.startsWith("[")) {
            val close = authority.indexOf(']')
            return close >= 0 && authority.length > close + 1 && authority[close + 1] == ':'
        }
        return authority.contains(':')
    }

    /** Sans requête ni fragment ni « / » final ; garde un sous-chemin (https://h/jellyfin). */
    fun normalize(uri: URI): String {
        val scheme = uri.scheme.lowercase()
        val host = uri.host.lowercase()
        val defaultPort = (scheme == "http" && uri.port == 80) || (scheme == "https" && uri.port == 443)
        val port = if (uri.port == -1 || defaultPort) "" else ":${uri.port}"
        val path = (uri.rawPath ?: "").trimEnd('/')
        val hostPart = if (host.contains(':') && !host.startsWith("[")) "[$host]" else host
        return "$scheme://$hostPart$port$path"
    }

    /** « 10.10.3 » ou « 10.11.0-rc1 » → [10, 10, 3]. null si illisible. */
    fun parseVersion(version: String?): List<Int>? {
        val m = versionPattern.find(version?.trim() ?: return null) ?: return null
        return listOf(m.groupValues[1].toInt(), m.groupValues[2].toInt(), m.groupValues[3].toIntOrNull() ?: 0)
    }

    fun isSupportedVersion(version: String?): Boolean {
        val v = parseVersion(version) ?: return false
        return v[0] > 10 || (v[0] == 10 && v[1] >= 9)
    }
}

/**
 * Découverte des serveurs du réseau local : « who is JellyfinServer? » en diffusion UDP sur 7359 ;
 * chaque serveur répond {Address, Id, Name}.
 */
object ServerDiscovery {
    const val PORT = 7359
    const val MESSAGE = "who is JellyfinServer?"

    /** Liste cumulée (sans doublon) des serveurs trouvés pendant [timeoutMs]. */
    fun discover(timeoutMs: Long = 3000): Flow<List<DiscoveredServer>> = flow {
        val found = LinkedHashMap<String, DiscoveredServer>()
        val socket = try {
            DatagramSocket().apply {
                broadcast = true
                soTimeout = 400
            }
        } catch (e: Exception) {
            emit(emptyList())
            return@flow
        }
        socket.use { s ->
            try {
                val payload = MESSAGE.toByteArray()
                s.send(DatagramPacket(payload, payload.size, InetAddress.getByName("255.255.255.255"), PORT))
            } catch (e: Exception) {
                emit(emptyList())
                return@flow
            }
            val deadline = System.currentTimeMillis() + timeoutMs
            val buffer = ByteArray(4096)
            while (System.currentTimeMillis() < deadline) {
                val packet = DatagramPacket(buffer, buffer.size)
                try {
                    s.receive(packet)
                } catch (e: SocketTimeoutException) {
                    continue
                } catch (e: Exception) {
                    break
                }
                val server = parse(String(packet.data, 0, packet.length)) ?: continue
                if (found.containsKey(server.id)) continue
                found[server.id] = server
                emit(found.values.toList())
            }
        }
        if (found.isEmpty()) emit(emptyList())
    }.flowOn(Dispatchers.IO)

    /** Réponse de découverte → serveur ; null si invalide. */
    fun parse(text: String): DiscoveredServer? {
        val r = runCatching { JellyfinJson.decodeFromString(DiscoveryResponse.serializer(), text) }.getOrNull() ?: return null
        val id = r.id?.takeIf { it.isNotEmpty() } ?: return null
        val candidates = ServerAddress.candidates(r.address ?: return null)
        val address = candidates.firstOrNull() ?: return null
        return DiscoveredServer(id, r.name?.takeIf { it.isNotEmpty() } ?: URI(address).host, address)
    }
}

/** Connexion : sonde de serveur, identifiants, Quick Connect, déconnexion. */
class AuthService(private val identity: ClientIdentity) {
    private fun client(baseUrl: String, token: String? = null) = JellyfinClient(baseUrl, identity) { token }

    /** Essaie chaque adresse candidate et renvoie le premier serveur Jellyfin valide. */
    suspend fun probe(input: String): JellyfinServer {
        val candidates = ServerAddress.candidates(input)
        if (candidates.isEmpty()) throw ApiException(ApiErrorKind.Unreachable)
        var last: ApiException? = null
        for (url in candidates) {
            try {
                val info = client(url).get<PublicSystemInfo>("System/Info/Public")
                if (info.id == null || (info.productName != null && info.productName != "Jellyfin Server")) {
                    last = ApiException(ApiErrorKind.NotJellyfin)
                    continue
                }
                if (!ServerAddress.isSupportedVersion(info.version)) {
                    throw ApiException(ApiErrorKind.UnsupportedVersion, info.version ?: "?")
                }
                return JellyfinServer(info.id, info.serverName?.takeIf { it.isNotEmpty() } ?: URI(url).host, url, info.version!!)
            } catch (e: ApiException) {
                if (e.kind == ApiErrorKind.UnsupportedVersion) throw e
                last = if (e.kind == ApiErrorKind.Unexpected || e.kind == ApiErrorKind.NotFound) ApiException(ApiErrorKind.NotJellyfin) else e
            }
        }
        throw last ?: ApiException(ApiErrorKind.Unreachable)
    }

    /** Utilisateurs visibles sur l'écran de connexion (vide s'ils sont masqués). */
    suspend fun publicUsers(server: JellyfinServer): List<PublicUser> = try {
        client(server.baseUrl).get<List<UserDto>>("Users/Public")
            .map { PublicUser(it.id, it.name ?: "", it.primaryImageTag, it.hasPassword ?: true) }
    } catch (e: ApiException) {
        emptyList()
    }

    suspend fun login(server: JellyfinServer, username: String, password: String): ActiveSession {
        val result = client(server.baseUrl).post<AuthenticationResult>(
            "Users/AuthenticateByName",
            JellyfinClient.json(AuthenticateUserByName(username, password)),
        )
        return toSession(server, result)
    }

    suspend fun isQuickConnectEnabled(server: JellyfinServer): Boolean = try {
        (client(server.baseUrl).get<JsonElement>("QuickConnect/Enabled") as? JsonPrimitive)?.booleanOrNull == true
    } catch (e: Exception) {
        false
    }

    suspend fun initiateQuickConnect(server: JellyfinServer): QuickConnectTicket {
        try {
            val r = client(server.baseUrl).post<QuickConnectResult>("QuickConnect/Initiate")
            return QuickConnectTicket(
                r.code ?: throw ApiException(ApiErrorKind.Unexpected, "Quick Connect sans code"),
                r.secret ?: throw ApiException(ApiErrorKind.Unexpected, "Quick Connect sans secret"),
            )
        } catch (e: ApiException) {
            // Le serveur répond 401 quand Quick Connect est désactivé.
            if (e.kind == ApiErrorKind.Unauthorized) throw ApiException(ApiErrorKind.QuickConnectDisabled)
            throw e
        }
    }

    /** Sonde le ticket jusqu'à autorisation (toutes les 3 s, 10 min max), puis échange le secret. */
    suspend fun awaitQuickConnect(server: JellyfinServer, ticket: QuickConnectTicket): ActiveSession {
        val client = client(server.baseUrl)
        val deadline = System.currentTimeMillis() + 10 * 60_000
        while (System.currentTimeMillis() < deadline) {
            try {
                val state = client.get<QuickConnectResult>("QuickConnect/Connect", listOf("secret" to ticket.secret))
                if (state.authenticated == true) {
                    val result = client.post<AuthenticationResult>(
                        "Users/AuthenticateWithQuickConnect",
                        JellyfinClient.json(QuickConnectDto(ticket.secret)),
                    )
                    return toSession(server, result)
                }
            } catch (e: ApiException) {
                // Ticket expiré (404) ou Quick Connect désactivé : abandon ; coupure réseau : on réessaie.
                if (e.kind in setOf(ApiErrorKind.NotFound, ApiErrorKind.Unexpected, ApiErrorKind.Unauthorized)) throw e
            }
            delay(3000)
        }
        throw ApiException(ApiErrorKind.Timeout, "Quick Connect expiré")
    }

    /** Révoque le jeton côté serveur (au mieux). */
    suspend fun logout(session: ActiveSession) {
        runCatching { client(session.server.baseUrl, session.token).postUnit("Sessions/Logout") }
    }

    private fun toSession(server: JellyfinServer, result: AuthenticationResult): ActiveSession {
        val user = result.user
        val token = result.accessToken
        if (user == null || token.isNullOrEmpty()) throw ApiException(ApiErrorKind.Unexpected, "Réponse d’authentification incomplète")
        return ActiveSession(server, Account(server.id, user.id, user.name ?: "", user.primaryImageTag), token)
    }
}
