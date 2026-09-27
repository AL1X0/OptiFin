import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Extrait une couleur d'accent d'une image RGBA (pixels bruts, petite taille).
///
/// On cherche la teinte **vive** dominante plutôt que la moyenne (souvent boueuse) :
/// histogramme de teintes sur 24 secteurs, pondéré par la saturation, en ignorant
/// les pixels trop sombres, trop clairs ou transparents. Retourne null si l'image
/// est quasi monochrome (l'appelant garde alors l'accent par défaut).
Color? dominantAccent(Uint8List rgba) {
  const buckets = 24;
  final weight = List<double>.filled(buckets, 0);
  final r = List<double>.filled(buckets, 0);
  final g = List<double>.filled(buckets, 0);
  final b = List<double>.filled(buckets, 0);

  for (var i = 0; i + 3 < rgba.length; i += 4) {
    if (rgba[i + 3] < 128) continue;
    final color = Color.fromARGB(255, rgba[i], rgba[i + 1], rgba[i + 2]);
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness < 0.12 || hsl.lightness > 0.9 || hsl.saturation < 0.2) continue;
    final bucket = (hsl.hue / 360 * buckets).floor() % buckets;
    final w = hsl.saturation * (1 - (hsl.lightness - 0.5).abs());
    weight[bucket] += w;
    r[bucket] += rgba[i] * w;
    g[bucket] += rgba[i + 1] * w;
    b[bucket] += rgba[i + 2] * w;
  }

  var best = -1;
  for (var i = 0; i < buckets; i++) {
    if (best < 0 || weight[i] > weight[best]) best = i;
  }
  final pixelCount = rgba.length / 4;
  // Moins de ~3 % de pixels colorés : image neutre.
  if (best < 0 || weight[best] <= 0 || weight[best] < pixelCount * 0.03 * 0.3) return null;
  final w = weight[best];
  return OFColors.normalizeAccent(Color.fromARGB(255, (r[best] / w).round(), (g[best] / w).round(), (b[best] / w).round()));
}

final _accentCache = <String, Color?>{};

/// Calcule l'accent d'une image réseau en la décodant à 24 px (quelques µs).
/// Le résultat est mémorisé par URL pour la session.
Future<Color?> accentFromUrl(Uri url) async {
  final key = url.toString();
  if (_accentCache.containsKey(key)) return _accentCache[key];

  final provider = ResizeImage(CachedNetworkImageProvider(key), width: 24, policy: ResizeImagePolicy.fit);
  final completer = Completer<ui.Image?>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) completer.complete(info.image.clone());
      stream.removeListener(listener);
    },
    onError: (_, _) {
      if (!completer.isCompleted) completer.complete(null);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);

  final image = await completer.future;
  if (image == null) return null;
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final accent = data == null ? null : dominantAccent(data.buffer.asUint8List());
    _accentCache[key] = accent;
    return accent;
  } finally {
    image.dispose();
  }
}
