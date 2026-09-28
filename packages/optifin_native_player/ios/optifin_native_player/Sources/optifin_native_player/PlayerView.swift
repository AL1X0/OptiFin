import AVFoundation
import AVKit
import Flutter
import UIKit

/// Vue dont la couche est un `AVPlayerLayer` : rendu HDR / Dolby Vision natif,
/// base du Picture-in-Picture (phase 5).
final class PlayerLayerView: UIView {
  override class var layerClass: AnyClass { AVPlayerLayer.self }

  var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

  /// Verre des commandes, au-dessus de l'image.
  let glass = GlassOverlayView()

  var player: AVPlayer? {
    get { playerLayer.player }
    set { playerLayer.player = newValue }
  }

  var gravity: AVLayerVideoGravity {
    get { playerLayer.videoGravity }
    set { playerLayer.videoGravity = newValue }
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .black
    isUserInteractionEnabled = false
    glass.frame = bounds
    glass.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(glass)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) non utilisé")
  }
}

final class PlayerPlatformView: NSObject, FlutterPlatformView {
  private let playerView: PlayerLayerView

  init(_ view: PlayerLayerView) {
    playerView = view
  }

  func view() -> UIView { playerView }
}

final class PlayerViewFactory: NSObject, FlutterPlatformViewFactory {
  private weak var plugin: OptifinNativePlayerPlugin?

  init(plugin: OptifinNativePlayerPlugin) {
    self.plugin = plugin
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    let params = args as? [String: Any]
    let view = PlayerLayerView(frame: frame)
    if let id = params?["playerId"] as? Int, let player = plugin?.player(id) {
      player.view = view
    }
    return PlayerPlatformView(view)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

/// Bouton AirPlay système (choix de l'Apple TV / du récepteur).
final class AirPlayViewFactory: NSObject, FlutterPlatformViewFactory {
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    let picker = AVRoutePickerView(frame: frame)
    picker.tintColor = .white
    picker.activeTintColor = .systemBlue
    picker.prioritizesVideoDevices = true
    picker.backgroundColor = .clear
    return SimplePlatformView(picker)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class SimplePlatformView: NSObject, FlutterPlatformView {
  private let content: UIView

  init(_ view: UIView) {
    content = view
  }

  func view() -> UIView { content }
}
