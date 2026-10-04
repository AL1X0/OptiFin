package app.optifin.tv.core.api

import app.optifin.tv.core.AppLog
import java.net.URLEncoder
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNamingStrategy
import kotlinx.serialization.serializer
import okhttp3.Call
import okhttp3.Callback
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.io.IOException

/** Identité du client envoyée dans l'en-tête `Authorization`. */
data class ClientIdentity(val clientName: String, val deviceName: String, val deviceId: String, val version: String) {
    /** `Authorization: MediaBrowser …` (Jellyfin 10.9+), valeurs encodées. */
    fun authorizationHeader(token: String?): String {
        fun q(v: String) = "\"" + URLEncoder.encode(v, "UTF-8").replace("+", "%20") + "\""
        val header = StringBuilder("MediaBrowser ")
            .append("Client=").append(q(clientName))
            .append(", Device=").append(q(deviceName))
            .append(", DeviceId=").append(q(deviceId))
            .append(", Version=").append(q(version))
        if (!token.isNullOrEmpty()) header.append(", Token=").append(q(token))
        return header.toString()
    }
}

/** JSON Jellyfin : propriétés PascalCase, champs inconnus ignorés, nulls omis à l'envoi. */
@OptIn(ExperimentalSerializationApi::class)
val JellyfinJson = Json {
    ignoreUnknownKeys = true
    explicitNulls = false
    coerceInputValues = true
    isLenient = true
    encodeDefaults = true
    namingStrategy = object : JsonNamingStrategy {
        override fun serialNameForJson(descriptor: SerialDescriptor, elementIndex: Int, serialName: String) =
            serialName.replaceFirstChar { it.uppercaseChar() }
    }
}

typealias Query = List<Pair<String, String?>>

/**
 * Client HTTP Jellyfin : en-tête d'authentification à chaque requête (jamais de jeton dans l'URL),
 * erreurs traduites en [ApiException].
 */
class JellyfinClient(
    val baseUrl: String,
    val identity: ClientIdentity,
    private val token: () -> String? = { null },
) {
    /** Appelé sur un 401 alors qu'un jeton était envoyé (jeton révoqué côté serveur). */
    var onUnauthorized: (() -> Unit)? = null

    val authorizationHeader: String get() = identity.authorizationHeader(token())

    fun resolve(path: String, query: Query = emptyList()): HttpUrl = Urls.resolve(baseUrl, path, query)

    suspend inline fun <reified T> get(path: String, query: Query = emptyList()): T =
        decode(serializer(), send("GET", path, query, null))

    suspend inline fun <reified T> post(path: String, body: RequestBody? = null, query: Query = emptyList()): T =
        decode(serializer(), send("POST", path, query, body))

    suspend inline fun <reified T> delete(path: String): T = decode(serializer(), send("DELETE", path, emptyList(), null))

    suspend fun postUnit(path: String, body: RequestBody? = null, query: Query = emptyList()) {
        send("POST", path, query, body)
    }

    suspend fun deleteUnit(path: String) {
        send("DELETE", path, emptyList(), null)
    }

    fun <T> decode(serializer: KSerializer<T>, text: String): T = try {
        JellyfinJson.decodeFromString(serializer, text.ifEmpty { "null" })
    } catch (e: Exception) {
        throw ApiException(ApiErrorKind.Unexpected, "Réponse illisible : ${e.message}")
    }

    /** Envoie la requête et renvoie le corps (vide si aucun). */
    suspend fun send(method: String, path: String, query: Query, body: RequestBody?): String {
        val url = resolve(path, query)
        val request = Request.Builder()
            .url(url)
            .header("Authorization", authorizationHeader)
            .header("Accept", "application/json")
            .method(method, body ?: if (method == "POST") EMPTY_BODY else null)
            .build()
        val started = System.currentTimeMillis()
        val response = try {
            http.newCall(request).await()
        } catch (e: IOException) {
            AppLog.w("http", "$method ${url.encodedPath} : ${e.message}")
            throw ApiException.from(e)
        }
        response.use { r ->
            AppLog.d("http", "$method ${url.encodedPath} → ${r.code} (${System.currentTimeMillis() - started} ms)")
            if (r.isSuccessful) return withContext(Dispatchers.IO) { r.body.string() }
            if (r.code == 401 && !token().isNullOrEmpty()) onUnauthorized?.invoke()
            throw ApiException.forStatus(r.code)
        }
    }

    companion object {
        val http: OkHttpClient = OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build()

        private val JSON_TYPE = "application/json; charset=utf-8".toMediaType()
        private val EMPTY_BODY = ByteArray(0).toRequestBody(null)

        fun json(element: JsonElement): RequestBody = element.toString().toRequestBody(JSON_TYPE)

        inline fun <reified T> json(value: T): RequestBody =
            JellyfinJson.encodeToString(serializer(), value).toRequestBody("application/json; charset=utf-8".toMediaType())
    }
}

/** Appel OkHttp suspendu, annulable. */
suspend fun Call.await(): Response = suspendCancellableCoroutine { cont ->
    cont.invokeOnCancellation { cancel() }
    enqueue(object : Callback {
        override fun onFailure(call: Call, e: IOException) {
            if (!cont.isCancelled) cont.resumeWith(Result.failure(e))
        }

        override fun onResponse(call: Call, response: Response) {
            cont.resumeWith(Result.success(response))
        }
    })
}

/** Construction d'URL serveur (pure, testée) : garde un sous-chemin de proxy (https://h/jellyfin). */
object Urls {
    fun resolve(baseUrl: String, path: String, query: Query = emptyList()): HttpUrl {
        val base = baseUrl.toHttpUrl()
        var relative = path.removePrefix("/")
        var existing = ""
        val q = relative.indexOf('?')
        if (q >= 0) {
            existing = relative.substring(q + 1)
            relative = relative.substring(0, q)
        }
        val basePath = base.encodedPath.let { if (it.endsWith("/")) it else "$it/" }
        val builder = base.newBuilder().encodedPath(basePath + relative).query(null)
        if (existing.isNotEmpty()) builder.encodedQuery(existing)
        for ((key, value) in query) if (value != null) builder.addQueryParameter(key, value)
        return builder.build()
    }
}
