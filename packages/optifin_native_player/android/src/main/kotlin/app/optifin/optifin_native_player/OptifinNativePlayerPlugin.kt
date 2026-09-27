package app.optifin.optifin_native_player

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Point d'entrée du plugin : capacités de l'appareil, création des lecteurs Media3,
 * fabrique des vues vidéo (SurfaceView en composition hybride).
 */
class OptifinNativePlayerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var messenger: BinaryMessenger
    private val players = mutableMapOf<Int, NativePlayer>()
    private var nextId = 1

    fun player(id: Int): NativePlayer? = players[id]

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        messenger = binding.binaryMessenger
        channel = MethodChannel(messenger, "optifin_native_player")
        channel.setMethodCallHandler(this)
        binding.platformViewRegistry.registerViewFactory("optifin_native_player/view", PlayerViewFactory(this))
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capabilities" -> result.success(CapabilitiesProbe.probe(context))
            "create" -> {
                val id = nextId++
                players[id] = NativePlayer(context, id, messenger) { players.remove(id) }
                result.success(id)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        players.values.toList().forEach { it.dispose() }
        players.clear()
    }
}
