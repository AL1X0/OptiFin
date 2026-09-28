import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo_fonts.dart';

/// Montage de la vidéo de lancement (1920×1080, 30 i/s) à partir des scènes
/// filmées par `capture_test.dart` : téléphone, textes animés, rotation, logo.
///
///   flutter test demo/stage_test.dart   →  build/demo/stage/%05d.png + build/demo/timeline.json
const _w = 1920.0;
const _h = 1080.0;

class Clip {
  const Clip(this.scene, this.from, this.to, this.caption, {this.landscape = false});

  final String scene;
  final int from;
  final int to;
  final Caption caption;
  final bool landscape;

  int get length => to - from;
}

class Caption {
  const Caption(this.overline, this.title, this.glow, {this.sub});

  final String overline;
  final String title;
  final String? sub;
  final Color glow;
}

const _home = Caption('OPTIFIN', 'Votre Jellyfin,\nen version cinéma.', Color(0xFFE0855A));
const _details = Caption('FICHES', 'Chaque film a\nson générique.', Color(0xFFD9774A), sub: '4K · Dolby Vision · Atmos, en un coup d’œil');
const _series = Caption('SÉRIES', 'Reprenez pile\nlà où vous étiez.', Color(0xFF3FC9A8));
const _find = Caption('BIBLIOTHÈQUES', 'Tout retrouver\nen quatre lettres.', Color(0xFF6C8CFF));
const _skip = Caption('LECTEUR', 'Passez l’intro\nd’un geste.', Color(0xFF3FC9A8));
const _engine = Caption(
  'LECTEUR HYBRIDE',
  'Le bon lecteur\npour chaque fichier.',
  Color(0xFF4DA3FF),
  sub: 'AVPlayer · Media3 · mpv, choisi automatiquement',
);
const _next = Caption('SÉRIES', 'L’épisode suivant\nest déjà prêt.', Color(0xFF3FC9A8));

const clips = [
  Clip('home', 0, 120, _home),
  Clip('details', 0, 111, _details),
  Clip('series', 0, 100, _series),
  Clip('library', 0, 60, _find),
  Clip('search', 0, 62, _find),
  Clip('player', 12, 80, _skip, landscape: true),
  Clip('player', 80, 150, _engine, landscape: true),
  Clip('player', 150, 231, _next, landscape: true),
];

const _rotation = 16; // images de rotation portrait → paysage
const _outro = 78;
const _cross = 5; // fondu entre deux plans d'une même orientation

// Téléphone : écran portrait (à droite) et paysage (centré, sous le texte).
const _portraitScreen = Rect.fromLTWH(1210, 62, 440, 956);
const _landscapeScreen = Rect.fromLTWH(265, 330, 1390, 642);
const _bezel = 13.0;

class _Timeline {
  _Timeline() {
    var t = 0;
    for (final (i, c) in clips.indexed) {
      if (c.landscape && i > 0 && !clips[i - 1].landscape) {
        rotationStart = t;
        t += _rotation;
      }
      starts.add(t);
      t += c.length;
    }
    outroStart = t;
    total = t + _outro;
  }

  final starts = <int>[];
  int rotationStart = -1;
  late final int outroStart;
  late final int total;

  /// Plan en cours à l'image [f] (null pendant la rotation et le logo).
  int? clipAt(int f) {
    for (var i = clips.length - 1; i >= 0; i--) {
      if (f >= starts[i] && f < starts[i] + clips[i].length) return i;
    }
    return null;
  }
}

double _ease(double t) => 1 - math.pow(1 - t.clamp(0.0, 1.0), 3).toDouble();
double _easeInOut(double t) {
  final x = t.clamp(0.0, 1.0);
  return x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;
}

void main() {
  testWidgets('montage de la vidéo OptiFin', (tester) async {
    await tester.runAsync(() async {
      await loadDemoFonts();
      final tl = _Timeline();
      final out = Directory('build/demo/stage')..createSync(recursive: true);
      for (final f in out.listSync()) {
        f.deleteSync();
      }
      final logo = await _decode(File('assets/branding/icon_1024.png').readAsBytesSync());

      final cache = <String, ui.Image>{};
      Future<ui.Image> frameOf(String scene, int i) async {
        final key = '$scene/$i';
        final hit = cache[key];
        if (hit != null) return hit;
        final file = File('build/demo/frames/$scene/${i.toString().padLeft(5, '0')}.png');
        final img = await _decode(file.readAsBytesSync());
        if (cache.length > 12) {
          final old = cache.keys.first;
          cache.remove(old)!.dispose();
        }
        return cache[key] = img;
      }

      // Repères pour la bande-son : débuts de plans, taps, rotation, logo.
      final taps = <double>[];
      for (final (i, c) in clips.indexed) {
        final file = File('build/demo/frames/${c.scene}/taps.json');
        if (!file.existsSync()) continue;
        for (final tap in (jsonDecode(file.readAsStringSync()) as List).cast<int>()) {
          if (tap >= c.from && tap < c.to) taps.add((tl.starts[i] + tap - c.from) / 30);
        }
      }
      File('build/demo/timeline.json').writeAsStringSync(
        jsonEncode({
          'fps': 30,
          'frames': tl.total,
          'taps': taps,
          'cuts': [for (final s in tl.starts) s / 30],
          'rotation': tl.rotationStart / 30,
          'outro': tl.outroStart / 30,
        }),
      );

      for (var f = 0; f < tl.total; f++) {
        final recorder = ui.PictureRecorder();
        final c = Canvas(recorder);
        await _paintFrame(c, f, tl, frameOf, logo);
        final image = await recorder.endRecording().toImage(_w.toInt(), _h.toInt());
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        File('${out.path}/${f.toString().padLeft(5, '0')}.png').writeAsBytesSync(png!.buffer.asUint8List());
      }
    });
  }, timeout: const Timeout(Duration(minutes: 40)));
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

Future<void> _paintFrame(
  Canvas c,
  int f,
  _Timeline tl,
  Future<ui.Image> Function(String scene, int i) frameOf,
  ui.Image logo,
) async {
  final ci = tl.clipAt(f);
  final inOutro = f >= tl.outroStart;
  final rotating = tl.rotationStart >= 0 && f >= tl.rotationStart && f < tl.rotationStart + _rotation;

  // Lueur : couleur du plan, en fondu d'un plan à l'autre.
  Color glow;
  if (ci != null) {
    final start = tl.starts[ci];
    final previous = ci > 0 ? clips[ci - 1].caption.glow : clips[ci].caption.glow;
    glow = Color.lerp(previous, clips[ci].caption.glow, _ease((f - start) / 15))!;
  } else {
    glow = inOutro ? const Color(0xFF4DA3FF) : clips.firstWhere((c) => c.landscape).caption.glow;
  }

  // Fond.
  c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), Paint()..color = const Color(0xFF030304));
  final landscape = ci != null ? clips[ci].landscape : (rotating || inOutro);
  final glowCenter = landscape ? const Offset(_w / 2, 650) : const Offset(1430, 540);
  c.drawCircle(
    glowCenter,
    900,
    Paint()
      ..shader = ui.Gradient.radial(glowCenter, 900, [glow.withValues(alpha: 0.28), glow.withValues(alpha: 0)]),
  );

  // Téléphone.
  var phoneAlpha = 1.0;
  if (inOutro) phoneAlpha = 1 - _ease((f - tl.outroStart) / 18);
  if (phoneAlpha > 0) {
    if (rotating) {
      final t = _easeInOut((f - tl.rotationStart) / _rotation);
      _phone(c, _rotated(t), angle: -math.pi / 2 * t, alpha: 1, screen: null);
    } else {
      final clip = ci != null ? clips[ci] : clips.last;
      final local = ci != null ? f - tl.starts[ci] : clip.length - 1;
      final rect = clip.landscape ? _landscapeScreen : _portraitScreen;
      final image = await frameOf(clip.scene, clip.from + local);
      _phone(c, rect, alpha: phoneAlpha, screen: image);
      // Fondu avec le plan précédent quand l'image « saute » (plans raccourcis).
      if (ci != null && ci > 0 && local < _cross) {
        final prev = clips[ci - 1];
        final continuous = prev.scene == clip.scene && prev.to == clip.from;
        if (prev.landscape == clip.landscape && !continuous) {
          final last = await frameOf(prev.scene, prev.to - 1);
          _screen(c, rect, last, alpha: 1 - local / _cross);
        }
      }
    }
  }

  // Textes.
  if (ci != null) {
    final clip = clips[ci];
    // Un même texte peut couvrir plusieurs plans : on remonte à son premier plan.
    var first = ci;
    while (first > 0 && identical(clips[first - 1].caption, clip.caption)) {
      first--;
    }
    var last = ci;
    while (last < clips.length - 1 && identical(clips[last + 1].caption, clip.caption)) {
      last++;
    }
    final begin = tl.starts[first];
    final end = tl.starts[last] + clips[last].length;
    final enter = _ease((f - begin - 4) / 14);
    final exit = 1 - _ease((f - (end - 9)) / 9);
    _caption(c, clip.caption, clip.landscape, opacity: math.min(enter, exit), rise: (1 - enter) * 28);
  }

  if (inOutro) _outroCard(c, f - tl.outroStart, logo);
}

Rect _rotated(double t) {
  final center = Offset.lerp(_portraitScreen.center, _landscapeScreen.center, t)!;
  // Pendant la rotation, le rectangle garde l'orientation portrait (la rotation du canvas fait le reste).
  final short = ui.lerpDouble(_portraitScreen.width, _landscapeScreen.height, t)!;
  final long = ui.lerpDouble(_portraitScreen.height, _landscapeScreen.width, t)!;
  return Rect.fromCenter(center: center, width: short, height: long);
}

void _phone(Canvas c, Rect rect, {double angle = 0, required double alpha, ui.Image? screen}) {
  final image = screen;
  c.save();
  if (angle != 0) {
    c.translate(rect.center.dx, rect.center.dy);
    c.rotate(angle);
    c.translate(-rect.center.dx, -rect.center.dy);
  }
  final radius = rect.shortestSide * 0.135;
  final body = RRect.fromRectAndRadius(rect.inflate(_bezel), Radius.circular(radius + _bezel));
  // Ombre portée douce.
  c.drawRRect(
    body.shift(const Offset(0, 24)),
    Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.7 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
  );
  c.drawRRect(body, Paint()..color = const Color(0xFF1B1B1E).withValues(alpha: alpha));
  c.drawRRect(
    body,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF4A4A50).withValues(alpha: alpha),
  );
  final inner = RRect.fromRectAndRadius(rect, Radius.circular(radius));
  c.drawRRect(inner, Paint()..color = const Color(0xFF000000));
  if (image != null) _screen(c, rect, image, alpha: alpha, radius: radius);
  c.restore();
}

void _screen(Canvas c, Rect screen, ui.Image image, {required double alpha, double? radius}) {
  final r = radius ?? screen.shortestSide * 0.135;
  c.save();
  c.clipRRect(RRect.fromRectAndRadius(screen, Radius.circular(r)));
  c.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    screen,
    Paint()
      ..filterQuality = FilterQuality.high
      ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
  );
  c.restore();
}

void _text(Canvas c, String text, TextStyle style, Offset at, {double maxWidth = 900, TextAlign align = TextAlign.left}) {
  final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, textAlign: align)
    ..layout(maxWidth: maxWidth);
  final dx = align == TextAlign.center ? at.dx - tp.width / 2 : at.dx;
  tp.paint(c, Offset(dx, at.dy));
}

double _textHeight(String text, TextStyle style, double maxWidth) =>
    (TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout(maxWidth: maxWidth))
        .height;

void _caption(Canvas c, Caption cap, bool landscape, {required double opacity, required double rise}) {
  if (opacity <= 0) return;
  final white = const Color(0xFFFFFFFF).withValues(alpha: opacity);
  final over = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 5,
    color: cap.glow.withValues(alpha: opacity),
  );
  final title = TextStyle(
    fontFamily: 'Roboto',
    fontSize: landscape ? 56 : 76,
    fontWeight: FontWeight.w700,
    height: 1.08,
    letterSpacing: -1.2,
    color: white,
  );
  final sub = TextStyle(
    fontFamily: 'Roboto',
    fontSize: landscape ? 24 : 30,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: const Color(0xFFA7A7AF).withValues(alpha: opacity),
  );
  if (landscape) {
    // Au-dessus du téléphone couché, sur une ligne.
    final line = cap.title.replaceAll('\n', ' ');
    _text(c, cap.overline, over, Offset(_w / 2, 88 + rise), align: TextAlign.center, maxWidth: 1600);
    _text(c, line, title, Offset(_w / 2, 124 + rise), align: TextAlign.center, maxWidth: 1700);
    if (cap.sub != null) _text(c, cap.sub!, sub, Offset(_w / 2, 200 + rise), align: TextAlign.center, maxWidth: 1600);
    return;
  }
  const x = 170.0;
  const maxWidth = 900.0;
  final titleH = _textHeight(cap.title, title, maxWidth);
  final subH = cap.sub == null ? 0.0 : 24 + _textHeight(cap.sub!, sub, maxWidth);
  final top = (_h - (44 + titleH + subH)) / 2 + rise;
  _text(c, cap.overline, over, Offset(x, top));
  _text(c, cap.title, title, Offset(x, top + 44), maxWidth: maxWidth);
  if (cap.sub != null) _text(c, cap.sub!, sub, Offset(x, top + 44 + titleH + 24), maxWidth: maxWidth);
}

void _outroCard(Canvas c, int f, ui.Image logo) {
  final t = _ease((f - 10) / 20);
  if (t <= 0) return;
  final rise = (1 - t) * 30;
  const size = 200.0;
  final logoRect = Rect.fromCenter(center: Offset(_w / 2, 390 + rise), width: size, height: size);
  c.save();
  c.clipRRect(RRect.fromRectAndRadius(logoRect, const Radius.circular(46)));
  c.drawImageRect(
    logo,
    Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
    logoRect,
    Paint()
      ..filterQuality = FilterQuality.high
      ..color = const Color(0xFFFFFFFF).withValues(alpha: t),
  );
  c.restore();
  c.drawRRect(
    RRect.fromRectAndRadius(logoRect, const Radius.circular(46)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF3A3A40).withValues(alpha: t),
  );
  _text(
    c,
    'OptiFin',
    TextStyle(fontFamily: 'Roboto', fontSize: 96, fontWeight: FontWeight.w700, letterSpacing: -2, color: const Color(0xFFFFFFFF).withValues(alpha: t)),
    Offset(_w / 2, 520 + rise),
    align: TextAlign.center,
  );
  final t2 = _ease((f - 22) / 18);
  _text(
    c,
    'Le client Jellyfin pour iPhone et Android',
    TextStyle(fontFamily: 'Roboto', fontSize: 34, color: const Color(0xFFA7A7AF).withValues(alpha: t2)),
    Offset(_w / 2, 648 + (1 - t2) * 20),
    align: TextAlign.center,
    maxWidth: 1400,
  );
  _text(
    c,
    'github.com/AL1X0/OptiFin',
    TextStyle(fontFamily: 'Roboto', fontSize: 28, fontWeight: FontWeight.w500, letterSpacing: 1, color: const Color(0xFF4DA3FF).withValues(alpha: t2)),
    Offset(_w / 2, 712 + (1 - t2) * 20),
    align: TextAlign.center,
    maxWidth: 1400,
  );
}
