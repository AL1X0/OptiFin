import 'dart:typed_data';

import 'package:flutter/painting.dart';

import 'demo_artwork.dart';
import 'demo_library.dart';

/// Toutes les illustrations de la démo, générées une fois puis servies à l'app
/// à la place du réseau (voir `OFImageSource.override`).
class DemoAssets {
  final _bytes = <String, Uint8List>{};
  final _providers = <String, ImageProvider>{};

  static final _transparent = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);

  Future<void> generate() async {
    for (final t in [...movies, ...series]) {
      _bytes['${t.id}/Primary'] = await renderPoster(
        t.scene,
        t.name,
        tagline: t.tagline,
        variant: t.variant,
        series: t.type == 'Series',
      );
      _bytes['${t.id}/Backdrop'] = await renderBackdrop(t.scene, variant: t.variant);
      _bytes['${t.id}/Thumb'] = _bytes['${t.id}/Backdrop']!;
      _bytes['${t.id}/Logo'] = await renderLogo(t.scene, t.name);
    }
    for (final s in seasons) {
      final parent = titleById(s.seriesId!);
      _bytes['${s.id}/Primary'] = await renderPoster(
        s.scene,
        parent.name,
        tagline: s.name,
        variant: s.variant,
        series: true,
      );
    }
    for (final e in episodes) {
      _bytes['${e.id}/Primary'] = await renderBackdrop(e.scene, variant: e.variant, width: 960);
    }
    for (final p in people) {
      _bytes['${p.id}/Primary'] = await renderPortrait(p.hue);
    }
    _bytes['demo-user/Primary'] = await renderPortrait(205);
    _bytes['lib-films/Primary'] = await renderLibrary(Scene.dunes, 'Films');
    _bytes['lib-series/Primary'] = await renderLibrary(Scene.aurora, 'Séries');
    for (var i = 0; i < 6; i++) {
      _bytes['chapter/$i'] = await renderBackdrop(Scene.aurora, variant: 40 + i, width: 480);
    }
  }

  Uint8List? bytes(String key) => _bytes[key];

  /// Clé d'une URL d'image Jellyfin : `Items/{id}/Images/{Type}[/{index}]`.
  static String? keyOf(String url) {
    final seg = Uri.parse(url).pathSegments;
    final i = seg.indexOf('Images');
    if (i < 1 || i + 1 >= seg.length) return null;
    final type = seg[i + 1];
    if (type == 'Chapter') return 'chapter/${seg.length > i + 2 ? seg[i + 2] : 0}';
    return '${seg[i - 1]}/$type';
  }

  ImageProvider provider(String url) {
    final key = keyOf(url) ?? url;
    return _providers.putIfAbsent(key, () => MemoryImage(_bytes[key] ?? _transparent));
  }

  /// Image « vidéo » d'un élément : l'épisode lui-même, sinon le backdrop du film.
  ImageProvider videoFrame(String itemId) {
    final key = _bytes.containsKey('$itemId/Backdrop') ? '$itemId/Backdrop' : '$itemId/Primary';
    return _providers.putIfAbsent(key, () => MemoryImage(_bytes[key] ?? _transparent));
  }

  /// Toutes les images, pour les décoder avant les captures.
  Iterable<ImageProvider> get all => [
    for (final k in _bytes.keys) _providers.putIfAbsent(k, () => MemoryImage(_bytes[k]!)),
  ];
}
