package app.optifin.optifin_native_player

import android.content.Context
import android.graphics.Color
import android.view.View
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Vue vidéo Media3 (SurfaceView par défaut : HDR et PiP), sans contrôles ni
 * sous-titres (dessinés par Flutter).
 */
@OptIn(UnstableApi::class)
class PlayerViewFactory(private val plugin: OptifinNativePlayerPlugin) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val playerId = ((args as? Map<*, *>)?.get("playerId") as? Number)?.toInt() ?: -1
        val view = PlayerView(context).apply {
            useController = false
            setShutterBackgroundColor(Color.BLACK)
            setBackgroundColor(Color.BLACK)
            setKeepContentOnPlayerReset(true)
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
