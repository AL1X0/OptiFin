import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Fond en verre natif iOS (Liquid Glass sur iOS 26, matériau flouté avant) : à poser
/// sous un contenu Flutter (icônes, libellés). Vide sur les autres plateformes.
class NativeGlassView extends StatelessWidget {
  const NativeGlassView({super.key, this.radius});

  /// Arrondi fixe ; null = pilule (moitié de la plus petite dimension).
  final double? radius;

  /// Coupé dans les rendus hors appareil (tests, démo) : pas de vue native.
  static bool enabled = true;

  /// true si la plateforme dessine réellement ce verre.
  static bool get supported => enabled && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    if (!supported) return const SizedBox.shrink();
    return UiKitView(
      viewType: 'optifin_native_player/glass',
      creationParams: {'radius': ?radius},
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
