import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

/// Source des images réseau de l'app (posters, backdrops, vignettes…).
///
/// Par défaut : téléchargement avec cache disque. Remplaçable par une source
/// locale pour les démos et captures d'écran (bibliothèque fictive, sans serveur).
abstract final class OFImageSource {
  static ImageProvider Function(String url, Map<String, String>? headers) _resolve = _network;
  static bool _overridden = false;

  static ImageProvider _network(String url, Map<String, String>? headers) =>
      CachedNetworkImageProvider(url, headers: headers);

  /// Image pour [url] (avec [headers] d'authentification si le serveur l'exige).
  static ImageProvider resolve(String url, {Map<String, String>? headers}) => _resolve(url, headers);

  /// true quand une source locale remplace le réseau.
  static bool get isOverridden => _overridden;

  /// Démos / captures : toutes les images viennent de [resolver].
  static void override(ImageProvider Function(String url) resolver) {
    _resolve = (url, _) => resolver(url);
    _overridden = true;
  }
}
