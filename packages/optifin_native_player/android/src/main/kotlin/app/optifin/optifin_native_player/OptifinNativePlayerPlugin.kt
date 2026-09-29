package app.optifin.optifin_native_player

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.ComponentCallbacks
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Point d'entrée du plugin : capacités de l'appareil, création des lecteurs Media3,
 * fabrique des vues vidéo (SurfaceView en composition hybride), Picture-in-Picture.
 *
 * Le PiP Android porte sur l'activité entière : il fonctionne quel que soit le moteur
 * (Media3 ou mpv). Flutter masque ses contrôles grâce à l'événement `pip`.
 */
class OptifinNativePlayerPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    EventChannel.StreamHandler {
    private lateinit var channel: MethodChannel
    private lateinit var pipChannel: EventChannel
    private lateinit var context: Context
    private lateinit var messenger: BinaryMessenger
    private val players = mutableMapOf<Int, NativePlayer>()
    private var nextId = 1

    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pipSink: EventChannel.EventSink? = null
    private var autoPip = false
    private var aspect = Rational(16, 9)
    private var inPip = false

    private val leaveHint = PluginRegistry.UserLeaveHintListener {
        // Avant Android 12 : pas d'entrée automatique, on la déclenche au départ de l'app.
        if (autoPip && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) enterPip()
    }

    private fun pipChanged(active: Boolean) {
        if (active == inPip) return
        inPip = active
        pipSink?.success(mapOf("active" to active))
    }

    // Filet de sécurité si l'activité hôte ne relaie pas onPictureInPictureModeChanged.
    private val configCallbacks = object : ComponentCallbacks {
        override fun onConfigurationChanged(newConfig: Configuration) {
            pipChanged(activity?.isInPictureInPictureMode ?: false)
        }

        @Deprecated("Deprecated in Java")
        override fun onLowMemory() {}
    }

    fun player(id: Int): NativePlayer? = players[id]

    companion object {
        private val instances = mutableSetOf<OptifinNativePlayerPlugin>()

        /** À appeler depuis `Activity.onPictureInPictureModeChanged` de l'app. */
        @JvmStatic
        fun notifyPictureInPicture(active: Boolean) {
            instances.toList().forEach { it.pipChanged(active) }
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        messenger = binding.binaryMessenger
        channel = MethodChannel(messenger, "optifin_native_player")
        channel.setMethodCallHandler(this)
        pipChannel = EventChannel(messenger, "optifin_native_player/pip")
        pipChannel.setStreamHandler(this)
        binding.platformViewRegistry.registerViewFactory("optifin_native_player/view", PlayerViewFactory(this))
        instances.add(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // Téléviseur : mode d'interface TV, fonctionnalité leanback ou Fire TV.
            "isTelevision" -> result.success(isTelevision())
            "capabilities" -> result.success(
                CapabilitiesProbe.probe(context) + mapOf(
                    "pictureInPicture" to (pipSupported() && !isTelevision()),
                    "airPlay" to false,
                    "television" to isTelevision(),
                ),
            )
            "create" -> {
                val id = nextId++
                players[id] = NativePlayer(context, id, messenger) { players.remove(id) }
                result.success(id)
            }
            "enterPip" -> {
                readAspect(call)
                result.success(enterPip())
            }
            "setAutoPip" -> {
                autoPip = call.argument<Boolean>("enabled") ?: false
                readAspect(call)
                applyParams()
                result.success(pipSupported())
            }
            else -> result.notImplemented()
        }
    }

    private fun readAspect(call: MethodCall) {
        val w = call.argument<Number>("width")?.toInt() ?: 0
        val h = call.argument<Number>("height")?.toInt() ?: 0
        // Android refuse les ratios extrêmes (au-delà de 2,39:1).
        if (w > 0 && h > 0) {
            val ratio = w.toDouble() / h
            aspect = when {
                ratio > 2.39 -> Rational(239, 100)
                ratio < 1 / 2.39 -> Rational(100, 239)
                else -> Rational(w, h)
            }
        }
    }

    private fun isTelevision(): Boolean {
        val uiMode = context.getSystemService(Context.UI_MODE_SERVICE) as? android.app.UiModeManager
        val pm = context.packageManager
        return uiMode?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            pm.hasSystemFeature("android.software.leanback") ||
            pm.hasSystemFeature("amazon.hardware.fire_tv")
    }

    private fun pipSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            context.packageManager.hasSystemFeature("android.software.picture_in_picture")

    private fun params(): PictureInPictureParams? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null
        val builder = PictureInPictureParams.Builder().setAspectRatio(aspect)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(autoPip).setSeamlessResizeEnabled(true)
        }
        return builder.build()
    }

    private fun applyParams() {
        val a = activity ?: return
        val p = params() ?: return
        if (pipSupported()) runCatching { a.setPictureInPictureParams(p) }
    }

    private fun enterPip(): Boolean {
        val a = activity ?: return false
        val p = params() ?: return false
        if (!pipSupported()) return false
        return runCatching { a.enterPictureInPictureMode(p) }.getOrDefault(false)
    }

    // ------------------------------------------------------------ Événements PiP

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        pipSink = events
    }

    override fun onCancel(arguments: Any?) {
        pipSink = null
    }

    // ------------------------------------------------------------ Activité

    private fun attach(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addOnUserLeaveHintListener(leaveHint)
        binding.activity.registerComponentCallbacks(configCallbacks)
    }

    private fun detach() {
        activityBinding?.removeOnUserLeaveHintListener(leaveHint)
        activity?.unregisterComponentCallbacks(configCallbacks)
        activityBinding = null
        activity = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attach(binding)

    override fun onDetachedFromActivityForConfigChanges() = detach()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = attach(binding)

    override fun onDetachedFromActivity() = detach()

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        instances.remove(this)
        channel.setMethodCallHandler(null)
        pipChannel.setStreamHandler(null)
        players.values.toList().forEach { it.dispose() }
        players.clear()
    }
}
