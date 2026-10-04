import 'package:flutter/widgets.dart';

/// Type d'appareil, fixé au démarrage (voir `bootstrap`).
abstract final class OFDevice {
  /// Mise en page « grand écran » : tablette.
  static bool large(BuildContext context) => MediaQuery.sizeOf(context).shortestSide >= 600;
}
