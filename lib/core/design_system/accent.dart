import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'image_source.dart';
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
  return OFColors.normalizeAccent(
    Color.fromARGB(255, (r[best] / w).round(), (g[best] / w).round(), (b[best] / w).round()),
  );
}

final _accentCache = <String, Color?>{};

/// Calcule l'accent d'une image réseau en la décodant à 24 px (quelques µs).
/// Le résultat est mémorisé par URL pour la session.
Future<Color?> accentFromUrl(Uri url) async {
  final key = url.toString();
  if (_accentCache.containsKey(key)) return _accentCache[key];

  final provider = ResizeImage(OFImageSource.resolve(key), width: 24, policy: ResizeImagePolicy.fit);
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

/// Couleur propre à un film : le sous-arbre prend l'accent tiré de son illustration
/// (barre de progression d'une carte, par exemple), sans toucher au reste de l'écran.
/// L'accent par défaut reste en place tant que l'image n'est pas analysée.
class FilmAccent extends StatefulWidget {
  const FilmAccent({super.key, required this.url, required this.child});

  /// Illustration à analyser (petite taille suffisante) ; null = accent par défaut.
  final Uri? url;
  final Widget child;

  @override
  State<FilmAccent> createState() => _FilmAccentState();
}

class _FilmAccentState extends State<FilmAccent> {
  Color? _accent;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(FilmAccent old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _resolve();
  }

  void _resolve() {
    final url = widget.url;
    if (url == null) return;
    final key = url.toString();
    if (_accentCache.containsKey(key)) {
      _accent = _accentCache[key];
      return;
    }
    unawaited(
      accentFromUrl(url).then((c) {
        if (mounted && widget.url == url && c != _accent) setState(() => _accent = c);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    if (accent == null) return widget.child;
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(primary: accent),
        progressIndicatorTheme: theme.progressIndicatorTheme.copyWith(color: accent),
      ),
      child: widget.child,
    );
  }
}
