import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Design tokens OptiFin. Voir docs/DESIGN_SYSTEM.md — aucune valeur en dur dans les écrans.
abstract final class OFColors {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF0E0E10);
  static const surfaceRaised = Color(0xFF18181B);
  static const surfaceGlass = Color(0x14FFFFFF); // blanc 8 %
  static const stroke = Color(0x1AFFFFFF); // blanc 10 %

  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xA3F5F5F7); // 64 %
  static const textTertiary = Color(0x66F5F5F7); // 40 %

  static const accentFallback = Color(0xFF4DA3FF);
  static const success = Color(0xFF34C759);
  static const warning = Color(0xFFFFB340);
  static const danger = Color(0xFFFF453A);

  /// Dégradé de lisibilité posé sur les backdrops.
  static const scrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0x66000000), Color(0xEB000000)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Ramène une couleur extraite d'un artwork dans une plage lisible sur fond noir.
  static Color normalizeAccent(Color source) {
    final hsl = HSLColor.fromColor(source);
    final lightness = hsl.lightness.clamp(0.55, 0.72);
    final saturation = hsl.saturation.clamp(0.35, 0.85);
    return hsl.withLightness(lightness).withSaturation(saturation).toColor();
  }
}

abstract final class OFSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Marge latérale d'un écran : [screenGutter] plus la zone de sécurité latérale
  /// (encoche ou Dynamic Island en paysage), pour que rien ne passe dessous.
  static double gutterOf(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return screenGutter(MediaQuery.sizeOf(context).width) + math.max(padding.left, padding.right);
  }

  /// Marge latérale d'écran selon la largeur disponible.
  static double screenGutter(double width) {
    if (width >= 1200) return 48;
    if (width >= 600) return 32;
    return 20;
  }
}

abstract final class OFRadius {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 16;
  static const double pill = 999;

  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
}

enum OFBreakpoint {
  compact,
  medium,
  expanded;

  static OFBreakpoint of(double width) {
    if (width >= 1024) return expanded;
    if (width >= 600) return medium;
    return compact;
  }

  double get posterWidth => switch (this) {
    compact => 112,
    medium => 136,
    expanded => 160,
  };
}

/// Durées et courbes. Toujours passer par [OFMotion.of] pour respecter
/// « Réduire les animations ».
class OFMotion {
  const OFMotion._(this._enabled);

  final bool _enabled;

  static const _fast = Duration(milliseconds: 120);
  static const _standard = Duration(milliseconds: 220);
  static const _emphasized = Duration(milliseconds: 300);

  static const Curve fastCurve = Curves.easeOut;
  static const Curve standardCurve = Cubic(0.2, 0, 0, 1);
  static const Curve emphasizedCurve = Cubic(0.05, 0.7, 0.1, 1);

  static OFMotion of(BuildContext context) => OFMotion._(!(MediaQuery.maybeDisableAnimationsOf(context) ?? false));

  bool get enabled => _enabled;
  Duration get fast => _enabled ? _fast : Duration.zero;
  Duration get standard => _enabled ? _standard : Duration.zero;
  Duration get emphasized => _enabled ? _emphasized : Duration.zero;
}
