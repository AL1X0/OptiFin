package app.optifin.tv.core.update

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import app.optifin.tv.BuildConfig
import app.optifin.tv.core.AppLog
import app.optifin.tv.core.api.UserFacingException
import app.optifin.tv.core.api.ApiException
import app.optifin.tv.core.api.JellyfinClient
import app.optifin.tv.core.api.await
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import okhttp3.Request

/**
 * Mise à jour intégrée : dernière release GitHub contenant l'APK TV (version 1.2.N la plus haute),
 * téléchargée dans le cache puis proposée à l'installateur Android.
 */
object AppUpdater {
    private const val RELEASES = "https://api.github.com/repos/AL1X0/OptiFin/releases?per_page=30"
    const val ASSET = "OptiFin-androidtv.apk"

    @Serializable
    private data class Asset(val name: String = "", val browserDownloadUrl: String = "", val size: Long = 0)

    @Serializable
    private data class Release(val tagName: String = "", val name: String? = null, val draft: Boolean = false, val assets: List<Asset> = emptyList())

    data class Update(val version: String, val url: String, val size: Long) {
        val sizeMb: Long get() = size / 1_000_000
    }

    private val json = kotlinx.serialization.json.Json { ignoreUnknownKeys = true; namingStrategy = kotlinx.serialization.json.JsonNamingStrategy.SnakeCase }

    /** Version plus récente que celle installée, ou null. */
    suspend fun check(): Update? {
        val request = Request.Builder().url(RELEASES).header("Accept", "application/vnd.github+json").build()
        val body = try {
            JellyfinClient.http.newCall(request).await().use { r ->
                if (!r.isSuccessful) throw ApiException.forStatus(r.code)
                withContext(Dispatchers.IO) { r.body.string() }
            }
        } catch (e: java.io.IOException) {
            throw ApiException.from(e)
        }
        val releases = json.decodeFromString<List<Release>>(body)
        val best = releases.filter { !it.draft }.mapNotNull { r ->
            val asset = r.assets.firstOrNull { it.name == ASSET } ?: return@mapNotNull null
            val version = r.tagName.removePrefix("tv-").toIntOrNull()?.let { "1.2.$it" } ?: return@mapNotNull null
            Update(version, asset.browserDownloadUrl, asset.size)
        }.maxWithOrNull { a, b -> compare(a.version, b.version) } ?: return null
        return if (compare(best.version, BuildConfig.VERSION_NAME.removeSuffix("-debug")) > 0) best else null
    }

    fun compare(a: String, b: String): Int {
        val pa = a.split('.').map { it.toIntOrNull() ?: 0 }
        val pb = b.split('.').map { it.toIntOrNull() ?: 0 }
        for (i in 0 until maxOf(pa.size, pb.size)) {
            val d = pa.getOrElse(i) { 0 }.compareTo(pb.getOrElse(i) { 0 })
            if (d != 0) return d
        }
        return 0
    }

    /** Télécharge l'APK puis ouvre l'installateur (autorisation « sources inconnues » demandée si besoin). */
    suspend fun install(context: Context, update: Update, progress: (Float) -> Unit) {
        if (Build.VERSION.SDK_INT >= 26 && !context.packageManager.canRequestPackageInstalls()) {
            context.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${context.packageName}"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            throw UserFacingException("Autorisez OptiFin à installer des applis, puis relancez la mise à jour.")
        }
        val dir = File(context.cacheDir, "updates").apply { mkdirs() }
        val file = File(dir, ASSET)
        val request = Request.Builder().url(update.url).build()
        try {
            JellyfinClient.http.newCall(request).await().use { r ->
                if (!r.isSuccessful) throw ApiException.forStatus(r.code)
                val total = r.body.contentLength().takeIf { it > 0 } ?: update.size
                withContext(Dispatchers.IO) {
                    r.body.byteStream().use { input ->
                        file.outputStream().use { output ->
                            val buffer = ByteArray(1 shl 16)
                            var done = 0L
                            while (true) {
                                val read = input.read(buffer)
                                if (read < 0) break
                                output.write(buffer, 0, read)
                                done += read
                                if (total > 0) withContext(Dispatchers.Main) { progress(done.toFloat() / total) }
                            }
                        }
                    }
                }
            }
        } catch (e: java.io.IOException) {
            throw ApiException.from(e)
        }
        AppLog.i("update", "Installation de la version ${update.version}")
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
        context.startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK))
    }

}
