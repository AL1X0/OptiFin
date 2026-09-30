import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Type d'appareil, fixé au démarrage (voir `bootstrap`).
abstract final class OFDevice {
  /// Téléviseur (Android TV, Google TV, Fire TV) : télécommande, interface « 10 pieds »,
  /// menu latéral, focus visible, pas de téléchargements ni de gestes tactiles.
  static bool tv = false;

  /// Ordinateur (Windows) : souris et clavier, fenêtre redimensionnable, survol, raccourcis,
  /// barre latérale permanente, pas de téléchargements ni de gestes tactiles.
  static bool desktop = switch (defaultTargetPlatform) {
    TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
    _ => false,
  };

  /// Mise en page « grand écran » : tablette, téléviseur ou ordinateur.
  static bool large(BuildContext context) => tv || desktop || MediaQuery.sizeOf(context).shortestSide >= 600;
}
