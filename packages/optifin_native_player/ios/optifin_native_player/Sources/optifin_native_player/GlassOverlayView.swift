import Flutter
import UIKit

/// Verre natif posé sur la vidéo, exactement sous les commandes Flutter qui en décrivent
/// la position (Liquid Glass sur iOS 26, matériau flouté avant).
///
/// Flutter ne peut pas flouter une vue native sans découpe arrondie, or une découpe
/// arrondie au-dessus d'une vue native efface ses commandes (Flutter 3.47). Le matériau
/// est donc dessiné ici, dans la vue vidéo elle-même : il réfracte l'image directement.
final class GlassOverlayView: UIView {
  private var items: [String: UIVisualEffectView] = [:]
  private var shown: [String: Bool] = [:]

  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    backgroundColor = .clear
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) non utilisé")
  }

  static func material() -> UIVisualEffect {
    #if compiler(>=6.2)
    if #available(iOS 26.0, *) {
      return UIGlassEffect(style: .regular)
    }
    #endif
    return UIBlurEffect(style: .systemUltraThinMaterialDark)
  }

  private static func number(_ value: Any?) -> CGFloat {
    CGFloat((value as? NSNumber)?.doubleValue ?? 0)
  }

  /// `specs` : [{id, x, y, w, h, r, visible}] en points, dans le repère de la vue vidéo.
  func update(_ specs: [[String: Any]]) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    var seen = Set<String>()
    for spec in specs {
      guard let id = spec["id"] as? String else { continue }
      seen.insert(id)
      let frame = CGRect(
        x: Self.number(spec["x"]),
        y: Self.number(spec["y"]),
        width: Self.number(spec["w"]),
        height: Self.number(spec["h"])
      )
      let radius = min(Self.number(spec["r"]), frame.width / 2, frame.height / 2)
      let visible = spec["visible"] as? Bool ?? true
      let view: UIVisualEffectView
      if let existing = items[id] {
        view = existing
      } else {
        view = UIVisualEffectView(effect: nil)
        view.clipsToBounds = true
        view.layer.cornerCurve = .continuous
        addSubview(view)
        items[id] = view
      }
      view.frame = frame
      view.layer.cornerRadius = radius
      if shown[id] != visible {
        shown[id] = visible
        // Apparition / disparition du verre : on anime l'effet, jamais l'alpha
        // (un effet visuel à alpha partiel perd son rendu).
        UIView.animate(withDuration: 0.22) {
          view.effect = visible ? Self.material() : nil
        }
      }
    }
    for (id, view) in items where !seen.contains(id) {
      view.removeFromSuperview()
      items[id] = nil
      shown[id] = nil
    }
    CATransaction.commit()
  }
}

/// Fond en verre natif pour une forme Flutter (barre d'onglets) : Liquid Glass sur
/// iOS 26, matériau flouté avant. Arrondi en pilule par défaut, ou `radius` fixe.
final class GlassBackgroundView: UIView {
  private let effectView = UIVisualEffectView(effect: GlassOverlayView.material())
  private let radius: CGFloat?

  init(frame: CGRect, radius: CGFloat?) {
    self.radius = radius
    super.init(frame: frame)
    backgroundColor = .clear
    isUserInteractionEnabled = false
    effectView.frame = bounds
    effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    effectView.clipsToBounds = true
    effectView.layer.cornerCurve = .continuous
    addSubview(effectView)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) non utilisé")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    effectView.layer.cornerRadius = radius ?? min(bounds.width, bounds.height) / 2
  }
}

final class GlassViewFactory: NSObject, FlutterPlatformViewFactory {
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    let params = args as? [String: Any]
    let radius = (params?["radius"] as? NSNumber).map { CGFloat($0.doubleValue) }
    return SimplePlatformView(GlassBackgroundView(frame: frame, radius: radius))
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}
