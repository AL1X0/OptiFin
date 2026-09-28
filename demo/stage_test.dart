import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo_fonts.dart';

/// Montage épuré de la vidéo de présentation (1920×1080, 30 i/s) à partir des scènes
/// filmées par `capture_test.dart` : fond noir, téléphone qui respire, une phrase par
/// plan, fondus lents ; ouverture et fin sur le logo.
///
///   flutter test demo/stage_test.dart   →  build/demo/stage/%05d.png + build/demo/timeline.json
const _w = 1920.0;
const _h = 1080.0;

class Clip {
  const Clip(this.scene, this.from, this.to, this.title, {this.sub, this.landscape = false, this.tint});

  final String scene;
  final int from;
  final int to;
  final String title;
  final String? sub;
  final bool landscape;

  /// Reflet très discret derrière le téléphone (couleur de l'illustration du plan).
  final Color? tint;

  int get length => to - from;
}

const clips = [
  Clip('home', 0, 150, 'Votre Jellyfin,\nen version cinéma.', tint: Color(0xFFE0855A)),
  Clip('details', 0, 109, 'Chaque film\na sa fiche.', sub: '4K · Dolby Vision · Atmos', tint: Color(0xFFD9774A)),
  Clip('series', 0, 132, 'Reprenez là où\nvous en étiez.', tint: Color(0xFF3FC9A8)),
  Clip(
    'downloads',
    0,
    82,
    'Même sans\nréseau.',
    sub: 'Films et saisons téléchargés en arrière-plan',
    tint: Color(0xFF6C8CFF),
  ),
  Clip(
    'player',
    12,
    110,
    'Un lecteur qui s’efface.',
    sub: 'Passer l’intro, épisode suivant, réglages en un geste',
    landscape: true,
    tint: Color(0xFF3FC9A8),
  ),
  Clip(
    'player',
    110,
    193,
    'Le bon moteur pour chaque fichier.',
    sub: 'AVPlayer · Media3 · mpv, choisi automatiquement',
    landscape: true,
    tint: Color(0xFF4DA3FF),
  ),
];

const _intro = 78;
const _rotation = 20; // portrait → paysage
const _outro = 96;
const _dissolve = 10; // fondu entre deux plans de même orientation

const _portraitScreen = Rect.fromLTWH(1150, 70, 432, 936);
const _landscapeScreen = Rect.fromLTWH(300, 330, 1320, 609);
const _bezel = 12.0;

class _Timeline {
  _Timeline() {
    var t = _intro;
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
        if (cache.length > 12) cache.remove(cache.keys.first)!.dispose();
        return cache[key] = img;
      }

      // Repères pour la bande-son : plans, taps, rotation, logo.
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
          'intro': 0.3,
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
  c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), Paint()..color = const Color(0xFF000000));

  if (f < _intro) {
    _brand(c, logo, f, fadeOut: _intro - f);
    return;
  }
  final ci = tl.clipAt(f);
  final inOutro = f >= tl.outroStart;
  final rotating = tl.rotationStart >= 0 && f >= tl.rotationStart && f < tl.rotationStart + _rotation;

  // Reflet de couleur, très discret, en fondu d'un plan à l'autre.
  Color tint;
  if (ci != null) {
    final previous = ci > 0 ? clips[ci - 1].tint! : clips[ci].tint!;
    tint = Color.lerp(previous, clips[ci].tint, _ease((f - tl.starts[ci]) / 24))!;
  } else {
    tint = inOutro ? clips.last.tint! : clips.firstWhere((c) => c.landscape).tint!;
  }
  final landscape = ci != null ? clips[ci].landscape : (rotating || inOutro);
  final center = landscape ? const Offset(_w / 2, 640) : _portraitScreen.center;
  var sceneAlpha = 1.0;
  if (f < _intro + 18) sceneAlpha = _ease((f - _intro) / 18);
  if (inOutro) sceneAlpha = 1 - _ease((f - tl.outroStart) / 20);
  c.drawCircle(
    center,
    760,
    Paint()
      ..shader = ui.Gradient.radial(center, 760, [
        tint.withValues(alpha: 0.13 * sceneAlpha),
        tint.withValues(alpha: 0),
      ]),
  );

  // Téléphone : léger zoom continu (le plan « respire »).
  if (sceneAlpha > 0) {
    if (rotating) {
      final t = _easeInOut((f - tl.rotationStart) / _rotation);
      _phone(c, _rotated(t), angle: -math.pi / 2 * t, alpha: 1, screen: null);
    } else {
      final clip = ci != null ? clips[ci] : clips.last;
      final local = ci != null ? f - tl.starts[ci] : clip.length - 1;
      final base = clip.landscape ? _landscapeScreen : _portraitScreen;
      final zoom = 1 + 0.018 * (local / clip.length);
      final rect = Rect.fromCenter(center: base.center, width: base.width * zoom, height: base.height * zoom);
      _phone(c, rect, alpha: sceneAlpha, screen: await frameOf(clip.scene, clip.from + local));
      // Fondu enchaîné depuis le plan précédent (même orientation, images non continues).
      if (ci != null && ci > 0 && local < _dissolve) {
        final prev = clips[ci - 1];
        final continuous = prev.scene == clip.scene && prev.to == clip.from;
        if (prev.landscape == clip.landscape && !continuous) {
          _screen(c, rect, await frameOf(prev.scene, prev.to - 1), alpha: 1 - _easeInOut(local / _dissolve));
        }
      }
    }
  }

  // Une phrase par plan.
  if (ci != null) {
    final clip = clips[ci];
    final start = tl.starts[ci];
    final end = start + clip.length;
    final enter = _ease((f - start - 6) / 16);
    final exit = 1 - _ease((f - (end - 10)) / 10);
    _caption(c, clip, opacity: math.min(enter, exit), rise: (1 - enter) * 18);
  }

  if (inOutro) _brand(c, logo, f - tl.outroStart - 14, outro: true);
}

Rect _rotated(double t) {
  final center = Offset.lerp(_portraitScreen.center, _landscapeScreen.center, t)!;
  final short = ui.lerpDouble(_portraitScreen.width, _landscapeScreen.height, t)!;
  final long = ui.lerpDouble(_portraitScreen.height, _landscapeScreen.width, t)!;
  return Rect.fromCenter(center: center, width: short, height: long);
}

void _phone(Canvas c, Rect rect, {double angle = 0, required double alpha, ui.Image? screen}) {
  c.save();
  if (angle != 0) {
    c.translate(rect.center.dx, rect.center.dy);
    c.rotate(angle);
    c.translate(-rect.center.dx, -rect.center.dy);
  }
  final radius = rect.shortestSide * 0.135;
  final body = RRect.fromRectAndRadius(rect.inflate(_bezel), Radius.circular(radius + _bezel));
  c.drawRRect(
    body.shift(const Offset(0, 30)),
    Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.8 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50),
  );
  c.drawRRect(body, Paint()..color = const Color(0xFF141416).withValues(alpha: alpha));
  // Tranche métallique : liseré plus clair en haut.
  c.drawRRect(
    body,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = ui.Gradient.linear(body.outerRect.topCenter, body.outerRect.bottomCenter, [
        const Color(0xFF6A6A72).withValues(alpha: alpha),
        const Color(0xFF2A2A2E).withValues(alpha: alpha),
      ]),
  );
  c.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), Paint()..color = const Color(0xFF000000));
  if (screen != null) _screen(c, rect, screen, alpha: alpha, radius: radius);
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

void _text(
  Canvas c,
  String text,
  TextStyle style,
  Offset at, {
  double maxWidth = 900,
  TextAlign align = TextAlign.left,
}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: align,
  )..layout(maxWidth: maxWidth);
  final dx = align == TextAlign.center ? at.dx - tp.width / 2 : at.dx;
  tp.paint(c, Offset(dx, at.dy));
}

double _textHeight(String text, TextStyle style, double maxWidth) => (TextPainter(
  text: TextSpan(text: text, style: style),
  textDirection: TextDirection.ltr,
)..layout(maxWidth: maxWidth)).height;

void _caption(Canvas c, Clip clip, {required double opacity, required double rise}) {
  if (opacity <= 0) return;
  final title = TextStyle(
    fontFamily: 'Roboto',
    fontSize: clip.landscape ? 52 : 72,
    fontWeight: FontWeight.w600,
    height: 1.1,
    letterSpacing: -1.4,
    color: const Color(0xFFF5F5F7).withValues(alpha: opacity),
  );
  final sub = TextStyle(
    fontFamily: 'Roboto',
    fontSize: clip.landscape ? 24 : 28,
    fontWeight: FontWeight.w400,
    height: 1.35,
    letterSpacing: 0.2,
    color: const Color(0xFF8E8E96).withValues(alpha: opacity),
  );
  if (clip.landscape) {
    _text(c, clip.title, title, Offset(_w / 2, 132 + rise), align: TextAlign.center, maxWidth: 1700);
    if (clip.sub != null) _text(c, clip.sub!, sub, Offset(_w / 2, 206 + rise), align: TextAlign.center, maxWidth: 1600);
    return;
  }
  const x = 220.0;
  const maxWidth = 820.0;
  final titleH = _textHeight(clip.title, title, maxWidth);
  final subH = clip.sub == null ? 0.0 : 26 + _textHeight(clip.sub!, sub, maxWidth);
  final top = (_h - (titleH + subH)) / 2 + rise;
  _text(c, clip.title, title, Offset(x, top), maxWidth: maxWidth);
  if (clip.sub != null) _text(c, clip.sub!, sub, Offset(x, top + titleH + 26), maxWidth: maxWidth);
}

/// Logo, nom et (en fin) accroche + adresse. [f] : image depuis l'apparition.
void _brand(Canvas c, ui.Image logo, int f, {bool outro = false, int? fadeOut}) {
  final t = _ease((f - 6) / 26);
  if (t <= 0) return;
  final out = fadeOut == null ? 1.0 : _ease(fadeOut / 14);
  final a = t * out;
  final scale = 0.94 + 0.06 * t;
  const size = 184.0;
  final cy = outro ? 390.0 : 470.0;
  final logoRect = Rect.fromCenter(center: Offset(_w / 2, cy), width: size * scale, height: size * scale);
  // Halo très doux derrière le logo.
  c.drawCircle(
    logoRect.center,
    420,
    Paint()
      ..shader = ui.Gradient.radial(logoRect.center, 420, [
        const Color(0xFF4DA3FF).withValues(alpha: 0.12 * a),
        const Color(0x004DA3FF),
      ]),
  );
  final r = Radius.circular(42 * scale);
  c.save();
  c.clipRRect(RRect.fromRectAndRadius(logoRect, r));
  c.drawImageRect(
    logo,
    Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
    logoRect,
    Paint()
      ..filterQuality = FilterQuality.high
      ..color = const Color(0xFFFFFFFF).withValues(alpha: a),
  );
  c.restore();
  final t2 = _ease((f - 16) / 22) * out;
  _text(
    c,
    'OptiFin',
    TextStyle(
      fontFamily: 'Roboto',
      fontSize: 84,
      fontWeight: FontWeight.w600,
      letterSpacing: -2,
      color: const Color(0xFFF5F5F7).withValues(alpha: t2),
    ),
    Offset(_w / 2, cy + 128 + (1 - t2) * 12),
    align: TextAlign.center,
  );
  if (!outro) return;
  final t3 = _ease((f - 30) / 22);
  _text(
    c,
    'Le client Jellyfin pour iPhone, iPad et Android',
    TextStyle(
      fontFamily: 'Roboto',
      fontSize: 30,
      color: const Color(0xFF8E8E96).withValues(alpha: t3),
    ),
    Offset(_w / 2, cy + 250 + (1 - t3) * 12),
    align: TextAlign.center,
    maxWidth: 1400,
  );
  _text(
    c,
    'github.com/AL1X0/OptiFin',
    TextStyle(
      fontFamily: 'Roboto',
      fontSize: 26,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.6,
      color: const Color(0xFFF5F5F7).withValues(alpha: 0.85 * t3),
    ),
    Offset(_w / 2, cy + 306 + (1 - t3) * 12),
    align: TextAlign.center,
    maxWidth: 1400,
  );
}
