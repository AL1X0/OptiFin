package app.optifin.optifin_native_player

import android.content.Context
import android.graphics.Color
import android.view.LayoutInflater
import android.view.View
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Vue vidéo Media3, sans contrôles ni sous-titres (dessinés par Flutter).
 *
 * - `texture = true` (vidéo SDR) : TextureView, compatible avec la composition par
 *   couche de texture de Flutter, la plus économe (pas de synchronisation des threads).
 * - sinon (HDR) : SurfaceView, seule capable d'afficher le HDR (composition hybride).
 */
@OptIn(UnstableApi::class)
class PlayerViewFactory(private val plugin: OptifinNativePlayerPlugin) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val playerId = (params?.get("playerId") as? Number)?.toInt() ?: -1
        val texture = params?.get("texture") as? Boolean ?: false
        val view = if (texture) {
            LayoutInflater.from(context).inflate(R.layout.optifin_player_texture, null, false) as PlayerView
        } else {
            PlayerView(context).apply {
                useController = false
                setShutterBackgroundColor(Color.BLACK)
                setBackgroundColor(Color.BLACK)
                setKeepContentOnPlayerReset(true)
            }
        }
        view.apply {
            subtitleView?.visibility = View.GONE
            isClickable = false
            isFocusable = false
        }
        plugin.player(playerId)?.attach(view)
        return object : PlatformView {
            override fun getView(): View = view

            override fun dispose() {
                plugin.player(playerId)?.detach(view)
            }
        }
    }
}
