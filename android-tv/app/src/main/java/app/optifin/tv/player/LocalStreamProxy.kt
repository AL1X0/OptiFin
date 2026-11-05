package app.optifin.tv.player

import app.optifin.tv.core.AppLog
import java.io.InputStream
import java.io.OutputStream
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.security.SecureRandom
import okhttp3.OkHttpClient
import okhttp3.Request

/**
 * Relais local pour mpv : le TLS de cette version de libmpv se bloque sur tout serveur HTTPS. mpv lit donc
 * en HTTP sur 127.0.0.1 et la vraie requête part par OkHttp (mêmes certificats et même pile réseau que le
 * lecteur natif). Les chemins sont conservés, pour que les adresses relatives des listes HLS restent justes.
 *
 * Écoute sur la boucle locale seulement ; la clé aléatoire de l'adresse empêche les autres applis de l'appareil
 * de s'en servir. Le jeton reste dans l'en-tête Authorization envoyé par mpv, jamais dans une adresse.
 */
class LocalStreamProxy(private val client: OkHttpClient) {
    // 127.0.0.1 explicitement : sur Android, getLoopbackAddress() peut renvoyer ::1, et mpv se voyait refuser la connexion.
    private val server = ServerSocket(0, 16, InetAddress.getByAddress(byteArrayOf(127, 0, 0, 1)))
    private val key = ByteArray(16).also(SecureRandom()::nextBytes).joinToString("") { "%02x".format(it) }

    init {
        Thread({
            while (!server.isClosed) {
                val socket = runCatching { server.accept() }.getOrNull() ?: break
                Thread({ serve(socket) }, "mpv-relais").apply { isDaemon = true }.start()
            }
        }, "mpv-relais-écoute").apply { isDaemon = true }.start()
    }

    /** Adresse à donner à mpv : seules les adresses HTTPS passent par le relais. */
    fun wrap(url: String): String =
        if (url.startsWith("https://", ignoreCase = true)) "http://127.0.0.1:${server.localPort}/$key/${url.substring(8)}" else url

    fun close() {
        runCatching { server.close() }
    }

    private fun serve(socket: Socket) {
        socket.use { s ->
            try {
                val input = s.getInputStream()
                val output = s.getOutputStream()
                val requestLine = readLine(input) ?: return
                val parts = requestLine.split(" ")
                if (parts.size < 2) return
                val headers = generateSequence { readLine(input)?.takeIf { it.isNotEmpty() } }
                    .mapNotNull { line -> line.indexOf(':').takeIf { it > 0 }?.let { line.substring(0, it).trim() to line.substring(it + 1).trim() } }
                    .toList()
                val prefix = "/$key/"
                if (parts[0] !in setOf("GET", "HEAD") || !parts[1].startsWith(prefix)) {
                    output.write("HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".toByteArray())
                    return
                }
                val request = Request.Builder().url("https://" + parts[1].removePrefix(prefix)).method(parts[0], null)
                for ((name, value) in headers) {
                    if (name.lowercase() in FORWARDED) request.header(name, value)
                }
                // Sans cela, OkHttp demande du gzip et le décompresse : tailles et Range ne correspondraient plus.
                request.header("Accept-Encoding", "identity")
                client.newCall(request.build()).execute().use { response ->
                    val head = StringBuilder("HTTP/1.1 ${response.code} ${response.message.ifEmpty { "OK" }}\r\n")
                    for (name in RETURNED) response.header(name)?.let { head.append("$name: $it\r\n") }
                    head.append("Connection: close\r\n\r\n")
                    output.write(head.toString().toByteArray())
                    if (parts[0] == "GET") response.body?.byteStream()?.let { copy(it, output) }
                    output.flush()
                }
            } catch (e: java.io.IOException) {
                // mpv ferme la connexion à chaque saut : c'est normal, rien à signaler.
                AppLog.d("mpv", "Relais interrompu : ${e.message}")
            } catch (e: IllegalArgumentException) {
                AppLog.w("mpv", "Relais : adresse refusée : ${e.message}")
            }
        }
    }

    private fun copy(input: InputStream, output: OutputStream) {
        val buffer = ByteArray(256 * 1024)
        while (true) {
            val read = input.read(buffer)
            if (read < 0) return
            output.write(buffer, 0, read)
        }
    }

    private fun readLine(input: InputStream): String? {
        val line = StringBuilder()
        while (line.length < MAX_LINE) {
            val c = input.read()
            if (c < 0) return if (line.isEmpty()) null else line.toString()
            if (c == '\n'.code) return line.toString().removeSuffix("\r")
            line.append(c.toChar())
        }
        return null
    }

    private companion object {
        const val MAX_LINE = 16 * 1024
        val FORWARDED = setOf("authorization", "range", "user-agent", "accept", "icy-metadata")
        val RETURNED = listOf("Content-Type", "Content-Length", "Content-Range", "Accept-Ranges", "Last-Modified", "ETag")
    }
}
