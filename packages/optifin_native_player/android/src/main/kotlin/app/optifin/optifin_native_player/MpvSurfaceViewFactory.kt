package app.optifin.optifin_native_player

import android.content.Context
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Surface vidéo Android pour libmpv (comme mpv-android ou Kodi) : mpv y dessine directement
 * (`--wid`), sans passer par une texture Flutter. Sur certains téléviseurs, la texture de
 * media_kit reste noire alors que mpv décode bien la vidéo (son seul).
 *
 * La surface est transmise à mpv sous forme de référence JNI globale (même helper que
 * media_kit) via le canal `optifin_native_player/mpv_surface` : `surface` {view, wid, width,
 * height} ; `wid = 0` quand elle disparaît.
 */
class MpvSurfaceViewFactory(messenger: BinaryMessenger) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    private val channel = MethodChannel(messenger, "optifin_native_player/mpv_surface")
    private val main = Handler(Looper.getMainLooper())

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val view = SurfaceView(context).apply {
            setBackgroundColor(Color.TRANSPARENT)
            isClickable = false
            isFocusable = false
        }
        var wid = 0L
        view.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {}

            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
                if (wid == 0L) wid = globalRef(holder.surface)
                if (wid == 0L) return
                channel.invokeMethod(
                    "surface",
                    mapOf("view" to viewId, "wid" to wid, "width" to width, "height" to height),
                )
            }

            override fun surfaceDestroyed(holder: SurfaceHolder) {
                val ref = wid
                wid = 0L
                if (ref == 0L) return
                channel.invokeMethod("surface", mapOf("view" to viewId, "wid" to 0L, "width" to 0, "height" to 0))
                // Laisse à mpv le temps de lâcher la surface (vo=null côté Dart) avant sa destruction.
                try {
                    Thread.sleep(150)
                } catch (e: InterruptedException) {
                }
                main.postDelayed({ deleteRef(ref) }, 5000)
            }
        })
        return object : PlatformView {
            override fun getView(): View = view

            override fun dispose() {}
        }
    }

    private fun helper(): Class<*> = Class.forName("com.alexmercerind.mediakitandroidhelper.MediaKitAndroidHelper")

    private fun globalRef(surface: Any): Long = try {
        helper().getDeclaredMethod("newGlobalObjectRef", Any::class.java).invoke(null, surface) as Long
    } catch (e: Throwable) {
        Log.e("OptiFin", "mpv : référence de surface impossible", e)
        0L
    }

    private fun deleteRef(ref: Long) {
        try {
            helper().getDeclaredMethod("deleteGlobalObjectRef", Long::class.javaPrimitiveType).invoke(null, ref)
        } catch (e: Throwable) {
            Log.e("OptiFin", "mpv : libération de surface impossible", e)
        }
    }
}
