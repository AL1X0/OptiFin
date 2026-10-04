package app.optifin.tv.core

import android.annotation.SuppressLint
import android.content.ContentUris
import android.content.Context
import android.net.Uri
import androidx.tvprovider.media.tv.TvContractCompat
import androidx.tvprovider.media.tv.WatchNextProgram
import app.optifin.tv.core.media.ImageUrls
import app.optifin.tv.core.media.MediaItem
import app.optifin.tv.core.media.MediaKind
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Rangée « Continuer à regarder » de l'écran d'accueil Android TV : lectures en cours et épisodes
 * à suivre. OK sur une vignette ouvre la fiche dans OptiFin (optifin://item/{id}).
 */
object WatchNext {
    @SuppressLint("RestrictedApi")
    suspend fun update(context: Context, resume: List<MediaItem>, nextUp: List<MediaItem>, images: ImageUrls?) = withContext(Dispatchers.IO) {
        try {
            clear(context)
            val now = System.currentTimeMillis()
            val entries = resume.map { it to TvContractCompat.WatchNextPrograms.WATCH_NEXT_TYPE_CONTINUE } +
                nextUp.map { it to TvContractCompat.WatchNextPrograms.WATCH_NEXT_TYPE_NEXT }
            entries.take(20).forEachIndexed { i, (item, type) ->
                val image = images?.maybe(item.landscape ?: item.backdrop ?: item.primary, 640)
                val builder = WatchNextProgram.Builder()
                    .setType(if (item.kind == MediaKind.Episode) TvContractCompat.PreviewPrograms.TYPE_TV_EPISODE else TvContractCompat.PreviewPrograms.TYPE_MOVIE)
                    .setWatchNextType(type)
                    .setLastEngagementTimeUtcMillis(now - i * 1000L)
                    .setTitle(if (item.kind == MediaKind.Episode) item.seriesName ?: item.name else item.name)
                    .setDescription(if (item.kind == MediaKind.Episode) listOfNotNull(item.episodeLabel, item.name).joinToString(" · ") else item.overview?.take(200))
                    .setIntentUri(Uri.parse("optifin://item/${item.id}"))
                    .setInternalProviderId(item.id)
                    .setPosterArtAspectRatio(TvContractCompat.PreviewPrograms.ASPECT_RATIO_16_9)
                image?.let { builder.setPosterArtUri(Uri.parse(it)) }
                item.runtimeMs?.let { builder.setDurationMillis(it.toInt()) }
                if (item.resumeMs > 0) builder.setLastPlaybackPositionMillis(item.resumeMs.toInt())
                if (item.kind == MediaKind.Episode) {
                    item.parentIndexNumber?.let { builder.setSeasonNumber(it) }
                    item.indexNumber?.let { builder.setEpisodeNumber(it) }
                    builder.setEpisodeTitle(item.name)
                }
                context.contentResolver.insert(TvContractCompat.WatchNextPrograms.CONTENT_URI, builder.build().toContentValues())
            }
        } catch (e: Exception) {
            // Lanceur sans « Continuer à regarder » (certains appareils) : sans conséquence.
            AppLog.d("watchnext", "Rangée « Continuer à regarder » indisponible : ${e.message}")
        }
    }

    /** Retire les vignettes d'OptiFin (seules celles de l'appli sont visibles par elle). */
    fun clear(context: Context) {
        runCatching {
            context.contentResolver.query(TvContractCompat.WatchNextPrograms.CONTENT_URI, arrayOf("_id"), null, null, null)?.use { c ->
                while (c.moveToNext()) {
                    context.contentResolver.delete(ContentUris.withAppendedId(TvContractCompat.WatchNextPrograms.CONTENT_URI, c.getLong(0)), null, null)
                }
            }
        }
    }
}
