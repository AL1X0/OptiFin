import Flutter
import UIKit

/// Point d'entrée du plugin : capacités de l'appareil, création des lecteurs,
/// fabrique des vues vidéo (`AVPlayerLayer` en PlatformView).
public class OptifinNativePlayerPlugin: NSObject, FlutterPlugin {
  private let messenger: FlutterBinaryMessenger
  private var players: [Int: NativePlayer] = [:]
  private var nextId = 1

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = OptifinNativePlayerPlugin(messenger: registrar.messenger())
    let channel = FlutterMethodChannel(name: "optifin_native_player", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.register(PlayerViewFactory(plugin: instance), withId: "optifin_native_player/view")
  }

  func player(_ id: Int) -> NativePlayer? { players[id] }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "capabilities":
      result(CapabilitiesProbe.probe())
    case "create":
      let id = nextId
      nextId += 1
      players[id] = NativePlayer(id: id, messenger: messenger) { [weak self] in
        self?.players[id] = nil
      }
      result(id)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    for player in players.values { player.dispose() }
    players.removeAll()
  }
}
