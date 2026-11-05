package app.optifin.optifin_native_player

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.mediarouter.media.MediaControlIntent
import androidx.mediarouter.media.MediaRouteSelector
import androidx.mediarouter.media.MediaRouter
import com.google.android.gms.cast.CastMediaControlIntent
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaLoadRequestData
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.MediaSeekOptions
import com.google.android.gms.cast.MediaStatus
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastOptions
import com.google.android.gms.cast.framework.OptionsProvider
import com.google.android.gms.cast.framework.SessionProvider
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.images.WebImage
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Récepteur média par défaut de Google : aucune appli à publier ni à enregistrer. */
class CastOptionsProvider : OptionsProvider {
    override fun getCastOptions(context: Context): CastOptions =
        CastOptions.Builder().setReceiverApplicationId(CastMediaControlIntent.DEFAULT_MEDIA_RECEIVER_APPLICATION_ID).build()

    override fun getAdditionalSessionProviders(context: Context): List<SessionProvider>? = null
}

/**
 * Chromecast : découverte des appareils, connexion, lancement d'un flux et commandes. La liste est
 * affichée par Flutter (pas la fenêtre système, qui exigerait une FragmentActivity). Sans services
 * Google (appareils Huawei, certains Android TV) : [available] renvoie faux, rien d'autre ne change.
 */
internal class CastController(private val context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "optifin_native_player/cast").also { it.setMethodCallHandler(this) }
    private val selector = MediaRouteSelector.Builder()
        .addControlCategory(CastMediaControlIntent.categoryForCast(CastMediaControlIntent.DEFAULT_MEDIA_RECEIVER_APPLICATION_ID))
        .build()
    private val discovery = object : MediaRouter.Callback() {}
    private var discovering = false

    private val cast: CastContext? by lazy {
        try {
            if (GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(context) != ConnectionResult.SUCCESS) null
            else CastContext.getSharedInstance(context)
        } catch (e: Exception) {
            Log.w("OptiFinCast", "Chromecast indisponible : ${e.message}")
            null
        }
    }

    private val router: MediaRouter get() = MediaRouter.getInstance(context)
    private val session get() = cast?.sessionManager?.currentCastSession
    private val media get() = session?.remoteMediaClient

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "available" -> result.success(cast != null)
                "startDiscovery" -> {
                    if (cast != null && !discovering) {
                        discovering = true
                        router.addCallback(selector, discovery, MediaRouter.CALLBACK_FLAG_REQUEST_DISCOVERY)
                    }
                    result.success(null)
                }
                "stopDiscovery" -> {
                    if (discovering) {
                        discovering = false
                        router.removeCallback(discovery)
                    }
                    result.success(null)
                }
                "devices" -> result.success(
                    if (cast == null) emptyList()
                    else router.routes.filter { it.isEnabled && !it.isDefault && it.matchesSelector(selector) }
                        .map { mapOf("id" to it.id, "name" to it.name) },
                )
                "connect" -> {
                    val route = router.routes.firstOrNull { it.id == call.argument<String>("id") }
                    if (route != null) router.selectRoute(route)
                    result.success(route != null)
                }
                "load" -> result.success(load(call))
                "state" -> result.success(state())
                "play" -> {
                    media?.play()
                    result.success(null)
                }
                "pause" -> {
                    media?.pause()
                    result.success(null)
                }
                "seek" -> {
                    media?.seek(MediaSeekOptions.Builder().setPosition(call.argument<Number>("ms")!!.toLong()).build())
                    result.success(null)
                }
                "disconnect" -> {
                    media?.stop()
                    cast?.sessionManager?.endCurrentSession(true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.w("OptiFinCast", "${call.method} : ${e.message}")
            result.error("cast", e.message, null)
        }
    }

    private fun load(call: MethodCall): Boolean {
        val client = media ?: return false
        val metadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE)
        metadata.putString(MediaMetadata.KEY_TITLE, call.argument<String>("title") ?: "")
        call.argument<String>("image")?.let { metadata.addImage(WebImage(Uri.parse(it))) }
        val info = MediaInfo.Builder(call.argument<String>("url")!!)
            .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
            .setContentType(call.argument<String>("contentType")!!)
            .setMetadata(metadata)
            .build()
        client.load(
            MediaLoadRequestData.Builder()
                .setMediaInfo(info)
                .setAutoplay(true)
                .setCurrentTime(call.argument<Number>("positionMs")?.toLong() ?: 0)
                .build(),
        )
        return true
    }

    private fun state(): Map<String, Any?> {
        val current = session
        val client = current?.remoteMediaClient
        val status = client?.mediaStatus
        return mapOf(
            "connected" to (current?.isConnected == true),
            "device" to current?.castDevice?.friendlyName,
            "positionMs" to (client?.approximateStreamPosition ?: 0L),
            "durationMs" to (client?.streamDuration ?: 0L),
            "paused" to (status?.playerState == MediaStatus.PLAYER_STATE_PAUSED),
            "finished" to (status?.playerState == MediaStatus.PLAYER_STATE_IDLE && status.idleReason == MediaStatus.IDLE_REASON_FINISHED),
            "error" to (status?.playerState == MediaStatus.PLAYER_STATE_IDLE && status.idleReason == MediaStatus.IDLE_REASON_ERROR),
        )
    }

    fun dispose() {
        if (discovering) router.removeCallback(discovery)
        channel.setMethodCallHandler(null)
    }
}
