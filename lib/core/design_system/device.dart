import 'package:flutter/widgets.dart';

/// Type d'appareil, fixé au démarrage (voir `bootstrap`).
abstract final class OFDevice {
  /// Téléviseur (Android TV, Google TV, Fire TV) : télécommande, interface « 10 pieds »,
  /// menu en haut, focus visible, pas de téléchargements ni de gestes tactiles.
  static bool tv = false;

  /// Mise en page « grand écran » : tablette ou téléviseur.
  static bool large(BuildContext context) => tv || MediaQuery.sizeOf(context).shortestSide >= 600;
}
