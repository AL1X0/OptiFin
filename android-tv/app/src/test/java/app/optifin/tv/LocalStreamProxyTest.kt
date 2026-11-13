package app.optifin.tv

import app.optifin.tv.player.LocalStreamProxy
import java.net.HttpURLConnection
import java.net.Socket
import java.net.URL
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Relais de mpv : le serveur HTTPS est simulé au niveau d'OkHttp, sans réseau. */
class LocalStreamProxyTest {
    private val seen = mutableListOf<okhttp3.Request>()
    private val file = ByteArray(1000) { it.toByte() }
    private val client = OkHttpClient.Builder().addInterceptor(Interceptor { chain ->
        val request = chain.request()
        synchronized(seen) { seen += request }
        val range = request.header("Range")?.removePrefix("bytes=")?.substringBefore('-')?.toIntOrNull()
        val body = if (range != null) file.copyOfRange(range, file.size) else file
        Response.Builder().request(request).protocol(Protocol.HTTP_1_1).code(if (range != null) 206 else 200).message("OK")
            .header("Content-Type", "video/x-matroska").header("Accept-Ranges", "bytes").header("Content-Length", "${body.size}")
            .header("Set-Cookie", "secret=1")
            .apply { if (range != null) header("Content-Range", "bytes $range-${file.size - 1}/${file.size}") }
            .body(body.toResponseBody("video/x-matroska".toMediaType())).build()
    }).build()
    private val proxy = LocalStreamProxy(client)

    @After
    fun close() = proxy.close()

    private fun open(url: String, vararg headers: Pair<String, String>) = (URL(url).openConnection() as HttpURLConnection).apply {
        headers.forEach { (k, v) -> setRequestProperty(k, v) }
    }

    @Test
    fun `seul le HTTPS passe par le relais, sur la boucle locale`() {
        assertEquals("http://192.168.1.2:8096/a", proxy.wrap("http://192.168.1.2:8096/a"))
        val wrapped = proxy.wrap("https://jelly.exemple.fr/Videos/1/stream?static=true")
        assertTrue(wrapped, wrapped.startsWith("http://127.0.0.1:"))
        assertTrue(wrapped, wrapped.endsWith("/jelly.exemple.fr/Videos/1/stream?static=true"))
    }

    @Test
    fun `transmet l'adresse, l'authentification et ne renvoie que les en-têtes utiles`() {
        val c = open(proxy.wrap("https://jelly.exemple.fr/Videos/1/stream?static=true&tag=x"), "Authorization" to "MediaBrowser Token=\"t\"", "Cookie" to "non=1")
        assertEquals(200, c.responseCode)
        assertEquals(file.toList(), c.inputStream.readBytes().toList())
        assertEquals("bytes", c.getHeaderField("Accept-Ranges"))
        assertEquals(null, c.getHeaderField("Set-Cookie"))
        val request = seen.single()
        assertEquals("https://jelly.exemple.fr/Videos/1/stream?static=true&tag=x", request.url.toString())
        assertEquals("MediaBrowser Token=\"t\"", request.header("Authorization"))
        assertEquals(null, request.header("Cookie"))
        assertEquals("identity", request.header("Accept-Encoding"))
    }

    @Test
    fun `les sauts passent par Range`() {
        val c = open(proxy.wrap("https://h.fr/f.mkv"), "Range" to "bytes=900-")
        assertEquals(206, c.responseCode)
        assertEquals("bytes 900-999/1000", c.getHeaderField("Content-Range"))
        assertEquals(100, c.inputStream.readBytes().size)
    }

    @Test
    fun `une adresse relative de liste HLS reste sur le bon serveur`() {
        val master = URL(proxy.wrap("https://h.fr/videos/1/master.m3u8?a=1"))
        val segment = URL(master, "hls1/main/0.ts?b=2")
        assertEquals(200, (segment.openConnection() as HttpURLConnection).responseCode)
        assertEquals("https://h.fr/videos/1/hls1/main/0.ts?b=2", seen.single().url.toString())
    }

    @Test
    fun `sans la clé, une autre appli de l'appareil est refusée`() {
        val wrapped = URL(proxy.wrap("https://h.fr/f.mkv"))
        val c = URL("http://127.0.0.1:${wrapped.port}/h.fr/f.mkv").openConnection() as HttpURLConnection
        assertEquals(403, c.responseCode)
        assertFalse(seen.isNotEmpty())
    }

    @Test
    fun `sans la clé, le relais répond 403 sans attendre les en-têtes`() {
        val port = URL(proxy.wrap("https://h.fr/f.mkv")).port
        Socket("127.0.0.1", port).use { socket ->
            socket.soTimeout = 2000
            val out = socket.getOutputStream()
            out.write("GET /h.fr/f.mkv HTTP/1.1\r\n".toByteArray())
            out.flush()
            val status = socket.getInputStream().bufferedReader().readLine()
            assertTrue("Réponse attendue 403, reçu : $status", status.startsWith("HTTP/1.1 403"))
        }
        assertFalse(seen.isNotEmpty())
    }

    @Test
    fun `un hôte non passé à wrap est refusé`() {
        val wrapped = URL(proxy.wrap("https://h.fr/f.mkv"))
        val key = wrapped.path.trimStart('/').substringBefore('/')
        val c = URL("http://127.0.0.1:${wrapped.port}/$key/autre.exemple.fr/secret").openConnection() as HttpURLConnection
        assertEquals(403, c.responseCode)
        assertFalse(seen.isNotEmpty())
    }
}
