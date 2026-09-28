/// Illustrations générées par code pour la bibliothèque de démo : paysages en
/// couches (ciel, astres, reliefs, brume), vignettage et grain. Aucune image externe.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

enum Scene { dunes, ocean, city, peaks, forest, nebula, arctic, canyon, aurora, storm }

/// Polices chargées par le harnais de capture.
const fontSans = 'Roboto';
const fontSerif = 'Georgia';
const fontWide = 'Bahnschrift';

class _Palette {
  const _Palette(this.sky, this.light, this.layers, {this.night = false, this.lightY = 0.55, this.lightX = 0.62});

  /// Ciel, du haut vers l'horizon.
  final List<Color> sky;

  /// Soleil / lune / lueur principale.
  final Color light;

  /// Reliefs, du plus lointain au plus proche.
  final List<Color> layers;
  final bool night;
  final double lightY;
  final double lightX;
}

_Palette _palette(Scene s, int variant) {
  final p = switch (s) {
    Scene.dunes => const _Palette(
      [Color(0xFF1B1030), Color(0xFF7A2E3A), Color(0xFFF2A15A)],
      Color(0xFFFFD28A),
      [Color(0xFFB65A3A), Color(0xFF8A3B2A), Color(0xFF5A2418), Color(0xFF2A0F0A)],
      lightY: 0.58,
    ),
    Scene.ocean => const _Palette(
      [Color(0xFF040A1C), Color(0xFF10264A), Color(0xFF355C8A)],
      Color(0xFFEAF2FF),
      [Color(0xFF0C1C36), Color(0xFF07142A)],
      night: true,
      lightY: 0.3,
    ),
    Scene.city => const _Palette(
      [Color(0xFF09031A), Color(0xFF2A0B3D), Color(0xFF8A2B6B)],
      Color(0xFFFF4FA3),
      [Color(0xFF1A0A2E), Color(0xFF110622), Color(0xFF070212)],
      night: true,
      lightY: 0.62,
    ),
    Scene.peaks => const _Palette(
      [Color(0xFF0D1B2A), Color(0xFF415A77), Color(0xFFE8A87C)],
      Color(0xFFFFE3B3),
      [Color(0xFF7D8FA8), Color(0xFF52637D), Color(0xFF2E3B52), Color(0xFF141C2B)],
      lightY: 0.6,
      lightX: 0.38,
    ),
    Scene.forest => const _Palette(
      [Color(0xFF0E1D19), Color(0xFF2D4A3E), Color(0xFFA9C2B2)],
      Color(0xFFF4F1D8),
      [Color(0xFF3F5E52), Color(0xFF26413A), Color(0xFF142822), Color(0xFF07130F)],
      lightY: 0.42,
      lightX: 0.7,
    ),
    Scene.nebula => const _Palette(
      [Color(0xFF02010A), Color(0xFF120828), Color(0xFF1C0F3A)],
      Color(0xFFB8A4FF),
      [Color(0xFF0B0718)],
      night: true,
      lightY: 0.72,
      lightX: 0.28,
    ),
    Scene.arctic => const _Palette(
      [Color(0xFF0A1A2F), Color(0xFF3B6E8F), Color(0xFFF7C59F)],
      Color(0xFFFFE0B5),
      [Color(0xFFBFD7EA), Color(0xFF8CB0CC), Color(0xFF4F7593)],
      lightY: 0.66,
    ),
    Scene.canyon => const _Palette(
      [Color(0xFF2B0F0E), Color(0xFF8C3B1E), Color(0xFFF2A65A)],
      Color(0xFFFFD08A),
      [Color(0xFFC0643A), Color(0xFF94401F), Color(0xFF5E2412), Color(0xFF2A0D06)],
      lightY: 0.5,
      lightX: 0.3,
    ),
    Scene.aurora => const _Palette(
      [Color(0xFF020814), Color(0xFF071B2E), Color(0xFF0F3B4A)],
      Color(0xFF6BFFC8),
      [Color(0xFF1B2F3F), Color(0xFF0E1C28), Color(0xFF060D14)],
      night: true,
      lightY: 0.25,
    ),
    Scene.storm => const _Palette(
      [Color(0xFF0A0E14), Color(0xFF1E2A36), Color(0xFF3E5566)],
      Color(0xFFD9ECFF),
      [Color(0xFF16222C), Color(0xFF0A1118)],
      lightY: 0.35,
      lightX: 0.7,
    ),
  };
  if (variant == 0) return p;
  // Variantes (épisodes) : décalage de l'astre, teinte légèrement tournée.
  final r = math.Random(variant);
  Color shift(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withHue((hsl.hue + (r.nextDouble() - 0.5) * 36) % 360).toColor();
  }

  return _Palette(
    [for (final c in p.sky) shift(c)],
    p.light,
    p.layers,
    night: p.night,
    lightY: (p.lightY + (r.nextDouble() - 0.5) * 0.2).clamp(0.2, 0.75),
    lightX: (p.lightX + (r.nextDouble() - 0.5) * 0.5).clamp(0.15, 0.85),
  );
}

/// Peint un paysage complet dans [size].
void paintScene(Canvas c, Size size, Scene scene, {int variant = 0}) {
  final w = size.width;
  final h = size.height;
  final p = _palette(scene, variant);
  final rnd = math.Random(scene.index * 1000 + variant);
  final horizon = h * (scene == Scene.nebula ? 0.9 : 0.62);

  // Ciel.
  c.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, horizon), p.sky, [0, 0.55, 1]),
  );
  // Bas de l'image (sous l'horizon) : prolonge le ciel assombri.
  c.drawRect(Rect.fromLTRB(0, horizon, w, h), Paint()..color = p.layers.last);

  final light = Offset(w * p.lightX, h * p.lightY);
  final unit = math.min(w, h);

  if (p.night) _stars(c, size, rnd, horizon);
  if (scene == Scene.nebula) _nebula(c, size, rnd);
  if (scene == Scene.aurora) _aurora(c, size, rnd);
  if (scene == Scene.storm) _clouds(c, size, rnd);

  // Halo puis astre.
  c.drawCircle(
    light,
    unit * 0.9,
    Paint()
      ..shader = ui.Gradient.radial(light, unit * 0.9, [p.light.withValues(alpha: p.night ? 0.22 : 0.45), p.light.withValues(alpha: 0)]),
  );
  if (scene != Scene.aurora && scene != Scene.storm) {
    c.drawCircle(light, unit * (p.night ? 0.05 : 0.08), Paint()..color = p.light);
  }
  if (scene == Scene.dunes) {
    // Deuxième soleil.
    final second = light.translate(-unit * 0.28, unit * 0.06);
    c.drawCircle(second, unit * 0.045, Paint()..color = const Color(0xFFFFB27A));
  }

  switch (scene) {
    case Scene.dunes:
      _ridges(c, size, rnd, p.layers, horizon, amplitude: 0.05, smooth: true, light: p.light);
    case Scene.peaks:
      _ridges(c, size, rnd, p.layers, horizon, amplitude: 0.22, sharp: true, light: p.light);
      _fog(c, size, horizon, p.sky.last.withValues(alpha: 0.35));
    case Scene.canyon:
      _mesas(c, size, rnd, p.layers, horizon);
    case Scene.forest:
      _ridges(c, size, rnd, p.layers.take(2).toList(), horizon, amplitude: 0.08);
      _fog(c, size, horizon, p.sky.last.withValues(alpha: 0.5));
      _pines(c, size, rnd, p.layers.skip(2).toList(), horizon);
      _fog(c, size, h * 0.95, p.sky.last.withValues(alpha: 0.25));
    case Scene.city:
      _city(c, size, rnd, p.layers, horizon);
    case Scene.ocean:
      _water(c, size, rnd, horizon, p.light, p.layers.first);
    case Scene.storm:
      _water(c, size, rnd, horizon, p.light, p.layers.first, rough: true);
      _lightning(c, size, rnd);
    case Scene.arctic:
      _ridges(c, size, rnd, [p.layers.first], horizon, amplitude: 0.1, sharp: true, light: p.light);
      _water(c, size, rnd, horizon, p.light, const Color(0xFF1D3A55));
      _floes(c, size, rnd, horizon, p.layers);
    case Scene.aurora:
      _ridges(c, size, rnd, p.layers, horizon, amplitude: 0.08, snow: true, light: p.light);
    case Scene.nebula:
      final planet = Offset(w * 0.78, h * 0.78);
      c.drawCircle(
        planet,
        unit * 0.34,
        Paint()
          ..shader = ui.Gradient.radial(
            planet.translate(-unit * 0.12, -unit * 0.14),
            unit * 0.5,
            [const Color(0xFF6D5BD0), const Color(0xFF231A52), const Color(0xFF07040F)],
            [0, 0.55, 1],
          ),
      );
  }

  _finish(c, size, rnd);
}

void _stars(Canvas c, Size s, math.Random r, double horizon) {
  final paint = Paint();
  for (var i = 0; i < 260; i++) {
    final o = Offset(r.nextDouble() * s.width, r.nextDouble() * horizon * 0.95);
    paint.color = const Color(0xFFFFFFFF).withValues(alpha: 0.15 + r.nextDouble() * 0.7);
    c.drawCircle(o, 0.4 + r.nextDouble() * 1.4 * s.width / 1600, paint);
  }
}

void _nebula(Canvas c, Size s, math.Random r) {
  const colors = [Color(0xFF7B3FE4), Color(0xFF1FB5C9), Color(0xFFE23E8C), Color(0xFF3B5BDB)];
  for (var i = 0; i < 9; i++) {
    final o = Offset(s.width * (0.15 + r.nextDouble() * 0.7), s.height * (0.15 + r.nextDouble() * 0.55));
    final rad = s.width * (0.18 + r.nextDouble() * 0.3);
    c.drawCircle(
      o,
      rad,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(o, rad, [colors[i % 4].withValues(alpha: 0.28), colors[i % 4].withValues(alpha: 0)]),
    );
  }
}

void _aurora(Canvas c, Size s, math.Random r) {
  for (var band = 0; band < 4; band++) {
    final path = Path();
    final base = s.height * (0.18 + band * 0.07);
    final phase = r.nextDouble() * math.pi * 2;
    path.moveTo(0, base);
    for (var x = 0.0; x <= s.width; x += s.width / 60) {
      path.lineTo(x, base + math.sin(x / s.width * math.pi * 2.5 + phase) * s.height * 0.08);
    }
    for (var x = s.width; x >= 0; x -= s.width / 60) {
      path.lineTo(x, base + s.height * 0.16 + math.sin(x / s.width * math.pi * 2 + phase) * s.height * 0.05);
    }
    path.close();
    final color = band.isEven ? const Color(0xFF3DFFB0) : const Color(0xFF6FE3FF);
    c.drawPath(
      path,
      Paint()
        ..blendMode = BlendMode.plus
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.width * 0.012)
        ..shader = ui.Gradient.linear(
          Offset(0, base),
          Offset(0, base + s.height * 0.3),
          [color.withValues(alpha: 0.26), color.withValues(alpha: 0)],
        ),
    );
  }
}

void _clouds(Canvas c, Size s, math.Random r) {
  for (var i = 0; i < 18; i++) {
    final o = Offset(r.nextDouble() * s.width, s.height * (0.05 + r.nextDouble() * 0.4));
    c.drawOval(
      Rect.fromCenter(center: o, width: s.width * (0.3 + r.nextDouble() * 0.4), height: s.height * (0.08 + r.nextDouble() * 0.1)),
      Paint()
        ..color = Color.lerp(const Color(0xFF2A3A48), const Color(0xFF55697A), r.nextDouble())!.withValues(alpha: 0.7)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.width * 0.03),
    );
  }
}

void _lightning(Canvas c, Size s, math.Random r) {
  final path = Path();
  var x = s.width * 0.72;
  var y = s.height * 0.12;
  path.moveTo(x, y);
  while (y < s.height * 0.62) {
    x += (r.nextDouble() - 0.5) * s.width * 0.05;
    y += s.height * (0.03 + r.nextDouble() * 0.05);
    path.lineTo(x, y);
  }
  c.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.004
      ..color = const Color(0xFFE6F3FF)
      ..maskFilter = MaskFilter.blur(BlurStyle.solid, s.width * 0.006),
  );
}

double _noise(double x, List<double> phases, {bool sharp = false}) {
  var v = 0.0;
  for (var i = 0; i < phases.length; i++) {
    final f = math.pow(2, i).toDouble();
    final s = math.sin(x * f * 3.1 + phases[i]);
    v += (sharp ? 1 - s.abs() * 2 : s) / f;
  }
  return v;
}

void _ridges(
  Canvas c,
  Size s,
  math.Random r,
  List<Color> layers,
  double horizon, {
  double amplitude = 0.1,
  bool sharp = false,
  bool smooth = false,
  bool snow = false,
  Color? light,
}) {
  for (var i = 0; i < layers.length; i++) {
    final depth = i / math.max(1, layers.length - 1);
    final phases = [for (var k = 0; k < 5; k++) r.nextDouble() * math.pi * 2];
    final base = horizon + s.height * (depth * 0.18 - 0.02);
    final amp = s.height * amplitude * (1 - depth * 0.35);
    final path = Path()..moveTo(0, s.height);
    for (var x = 0.0; x <= s.width + 1; x += s.width / 120) {
      final n = _noise(x / s.width, phases, sharp: sharp);
      path.lineTo(x, base - (smooth ? (n + 1.2) * amp * 0.6 : n * amp + amp * 0.4));
    }
    path
      ..lineTo(s.width, s.height)
      ..close();
    final top = base - amp * 1.6;
    c.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, top),
          Offset(0, base + s.height * 0.2),
          [Color.lerp(layers[i], light ?? layers[i], smooth ? 0.25 : (snow ? 0.12 : 0.1))!, layers[i]],
        ),
    );
    if (snow && i == 0) {
      c.drawPath(path, Paint()..color = const Color(0xFFBFD9E6).withValues(alpha: 0.12));
    }
  }
}

void _mesas(Canvas c, Size s, math.Random r, List<Color> layers, double horizon) {
  for (var i = 0; i < layers.length; i++) {
    final depth = i / (layers.length - 1);
    final base = horizon + s.height * depth * 0.2;
    final path = Path()..moveTo(0, s.height);
    var x = 0.0;
    var y = base - s.height * (0.08 + r.nextDouble() * 0.12) * (1 - depth * 0.3);
    path.lineTo(0, y);
    while (x < s.width) {
      final flat = s.width * (0.08 + r.nextDouble() * 0.16);
      path.lineTo(x + flat, y);
      x += flat;
      final drop = s.height * (r.nextDouble() - 0.45) * 0.14;
      final nextY = (y + drop).clamp(horizon - s.height * 0.3, base + s.height * 0.05);
      path.lineTo(x + s.width * 0.02, nextY);
      x += s.width * 0.02;
      y = nextY;
    }
    path
      ..lineTo(s.width, s.height)
      ..close();
    c.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, base - s.height * 0.25),
          Offset(0, s.height),
          [Color.lerp(layers[i], const Color(0xFFFFC080), 0.25)!, layers[i]],
        ),
    );
  }
}

void _pines(Canvas c, Size s, math.Random r, List<Color> layers, double horizon) {
  for (var i = 0; i < layers.length; i++) {
    final depth = i / math.max(1, layers.length - 1);
    final paint = Paint()..color = layers[i];
    final base = horizon + s.height * (0.08 + depth * 0.22);
    final treeH = s.height * (0.16 + depth * 0.22);
    var x = -r.nextDouble() * s.width * 0.05;
    while (x < s.width) {
      final hh = treeH * (0.6 + r.nextDouble() * 0.6);
      final ww = hh * 0.32;
      final path = Path()
        ..moveTo(x, base)
        ..lineTo(x + ww / 2, base - hh)
        ..lineTo(x + ww, base)
        ..close();
      c.drawPath(path, paint);
      x += ww * (0.45 + r.nextDouble() * 0.5);
    }
    c.drawRect(Rect.fromLTRB(0, base - 1, s.width, s.height), paint);
  }
}

void _fog(Canvas c, Size s, double y, Color color) {
  c.drawRect(
    Rect.fromLTRB(0, y - s.height * 0.18, s.width, y + s.height * 0.12),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, y - s.height * 0.18),
        Offset(0, y + s.height * 0.12),
        [color.withValues(alpha: 0), color, color.withValues(alpha: 0)],
        [0, 0.55, 1],
      ),
  );
}

void _city(Canvas c, Size s, math.Random r, List<Color> layers, double horizon) {
  const neon = [Color(0xFFFF4FA3), Color(0xFF3CE6FF), Color(0xFFFFC857), Color(0xFFB36BFF)];
  for (var i = 0; i < layers.length; i++) {
    final depth = i / (layers.length - 1);
    final base = horizon + s.height * (0.06 + depth * 0.3);
    var x = -s.width * 0.02;
    while (x < s.width) {
      final bw = s.width * (0.04 + r.nextDouble() * 0.07) * (0.7 + depth);
      final bh = s.height * (0.12 + r.nextDouble() * 0.4) * (1.1 - depth * 0.3);
      final rect = Rect.fromLTWH(x, base - bh, bw, bh + s.height);
      c.drawRect(rect, Paint()..color = layers[i]);
      // Fenêtres allumées.
      final win = Paint();
      final step = s.width * 0.008 * (0.8 + depth);
      for (var wy = rect.top + step; wy < base - step; wy += step * 1.8) {
        for (var wx = rect.left + step * 0.6; wx < rect.right - step; wx += step * 1.4) {
          if (r.nextDouble() < 0.28) {
            win.color = (r.nextDouble() < 0.8 ? const Color(0xFFFFE2A8) : neon[r.nextInt(4)])
                .withValues(alpha: 0.35 + depth * 0.4);
            c.drawRect(Rect.fromLTWH(wx, wy, step * 0.6, step * 0.8), win);
          }
        }
      }
      // Enseigne néon.
      if (r.nextDouble() < 0.35 && depth > 0.4) {
        final color = neon[r.nextInt(4)];
        final sign = Rect.fromLTWH(rect.left + bw * 0.2, rect.top + bh * 0.2, bw * 0.12, bh * 0.35);
        c.drawRect(
          sign,
          Paint()
            ..color = color
            ..maskFilter = MaskFilter.blur(BlurStyle.solid, s.width * 0.004),
        );
      }
      x += bw * (0.9 + r.nextDouble() * 0.3);
    }
  }
}

void _water(Canvas c, Size s, math.Random r, double horizon, Color light, Color water, {bool rough = false}) {
  c.drawRect(
    Rect.fromLTRB(0, horizon, s.width, s.height),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, horizon),
        Offset(0, s.height),
        [Color.lerp(water, light, 0.12)!, water, Color.lerp(water, const Color(0xFF000000), 0.5)!],
        [0, 0.4, 1],
      ),
  );
  // Reflet de l'astre et vagues.
  final paint = Paint();
  for (var i = 0; i < 140; i++) {
    final t = r.nextDouble();
    final y = horizon + (s.height - horizon) * t * t;
    final spread = s.width * (0.04 + t * 0.2);
    final x = s.width * 0.62 + (r.nextDouble() - 0.5) * spread * 2;
    paint.color = light.withValues(alpha: (1 - t) * 0.5 * r.nextDouble());
    c.drawRect(Rect.fromCenter(center: Offset(x, y), width: s.width * (0.01 + r.nextDouble() * 0.05), height: 1.5 + t * 2), paint);
  }
  if (rough) {
    for (var i = 0; i < 60; i++) {
      final y = horizon + (s.height - horizon) * r.nextDouble();
      paint.color = const Color(0xFFFFFFFF).withValues(alpha: 0.06);
      c.drawRect(Rect.fromLTWH(r.nextDouble() * s.width, y, s.width * 0.08, 2), paint);
    }
  }
}

void _floes(Canvas c, Size s, math.Random r, double horizon, List<Color> layers) {
  for (var i = 0; i < 9; i++) {
    final t = 0.2 + r.nextDouble() * 0.8;
    final y = horizon + (s.height - horizon) * t;
    final w = s.width * (0.08 + t * 0.2);
    final x = r.nextDouble() * s.width;
    final path = Path()
      ..moveTo(x, y)
      ..lineTo(x + w * 0.2, y - w * 0.05)
      ..lineTo(x + w * 0.85, y - w * 0.04)
      ..lineTo(x + w, y)
      ..lineTo(x + w * 0.7, y + w * 0.05)
      ..close();
    c.drawPath(path, Paint()..color = Color.lerp(layers[0], layers[2], r.nextDouble())!);
  }
}

void _finish(Canvas c, Size s, math.Random r) {
  // Vignettage.
  final center = s.center(Offset.zero);
  c.drawRect(
    Offset.zero & s,
    Paint()
      ..shader = ui.Gradient.radial(
        center,
        s.longestSide * 0.75,
        [const Color(0x00000000), const Color(0x00000000), const Color(0x99000000)],
        [0, 0.55, 1],
      ),
  );
  // Grain léger.
  final grain = Paint();
  final count = (s.width * s.height / 900).round();
  for (var i = 0; i < count; i++) {
    grain.color = (r.nextBool() ? const Color(0xFFFFFFFF) : const Color(0xFF000000)).withValues(alpha: 0.035);
    c.drawRect(Rect.fromLTWH(r.nextDouble() * s.width, r.nextDouble() * s.height, 1.2, 1.2), grain);
  }
}

// ------------------------------------------------------------------ Textes

void _text(
  Canvas c,
  String text, {
  required Offset center,
  required double maxWidth,
  required TextStyle style,
  TextAlign align = TextAlign.center,
}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: align,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

/// Style de titre propre à chaque univers (pour les affiches et les logos).
TextStyle titleStyle(Scene scene, double size) => switch (scene) {
  Scene.ocean || Scene.arctic || Scene.aurora || Scene.forest => TextStyle(
    fontFamily: fontSerif,
    fontSize: size,
    fontWeight: FontWeight.w400,
    letterSpacing: size * 0.02,
    color: const Color(0xFFFFFFFF),
    height: 1.05,
  ),
  Scene.city || Scene.storm => TextStyle(
    fontFamily: fontWide,
    fontSize: size * 0.95,
    fontWeight: FontWeight.w700,
    letterSpacing: size * 0.08,
    color: const Color(0xFFFFFFFF),
    height: 1.05,
  ),
  _ => TextStyle(
    fontFamily: fontSans,
    fontSize: size,
    fontWeight: FontWeight.w900,
    letterSpacing: size * 0.06,
    color: const Color(0xFFFFFFFF),
    height: 1.05,
  ),
};

String _titleCase(Scene scene, String title) =>
    switch (scene) { Scene.ocean || Scene.arctic || Scene.aurora || Scene.forest => title, _ => title.toUpperCase() };

// ------------------------------------------------------------------ Rendu

Future<Uint8List> _render(int w, int h, void Function(Canvas c, Size s) paint) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paint(canvas, Size(w.toDouble(), h.toDouble()));
  final image = await recorder.endRecording().toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

/// Paysage 16:9 (backdrops, vignettes d'épisodes).
Future<Uint8List> renderBackdrop(Scene scene, {int variant = 0, int width = 1600}) =>
    _render(width, width * 9 ~/ 16, (c, s) => paintScene(c, s, scene, variant: variant));

/// Affiche 2:3 : paysage, accroche en haut, titre et « billing block » en bas.
Future<Uint8List> renderPoster(Scene scene, String title, {String? tagline, int variant = 0, bool series = false}) =>
    _render(600, 900, (c, s) {
      paintScene(c, s, scene, variant: variant);
      c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, s.height * 0.45),
            Offset(0, s.height),
            [const Color(0x00000000), const Color(0xE6000000)],
          ),
      );
      if (tagline != null) {
        _text(
          c,
          tagline.toUpperCase(),
          center: Offset(s.width / 2, s.height * 0.08),
          maxWidth: s.width * 0.8,
          style: const TextStyle(fontFamily: fontSans, fontSize: 15, letterSpacing: 3, color: Color(0xCCFFFFFF)),
        );
      }
      _text(
        c,
        _titleCase(scene, title),
        center: Offset(s.width / 2, s.height * 0.8),
        maxWidth: s.width * 0.86,
        style: titleStyle(scene, title.length > 14 ? 50 : 62),
      );
      _text(
        c,
        series ? 'UNE SÉRIE ORIGINALE   ·   PRODUCTIONS OPTIFIN   ·   TOUS LES ÉPISODES' : 'UN FILM DE CAMILLE ARNAUD   ·   PRODUCTIONS OPTIFIN   ·   BIENTÔT',
        center: Offset(s.width / 2, s.height * 0.95),
        maxWidth: s.width * 0.9,
        style: const TextStyle(fontFamily: fontSans, fontSize: 9, letterSpacing: 1.6, color: Color(0x99FFFFFF)),
      );
    });

/// Logo de titre sur fond transparent (posé sur les backdrops).
Future<Uint8List> renderLogo(Scene scene, String title) => _render(1000, 300, (c, s) {
  _text(
    c,
    _titleCase(scene, title),
    center: s.center(Offset.zero),
    maxWidth: s.width * 0.96,
    style: titleStyle(scene, title.length > 14 ? 96 : 118).copyWith(
      shadows: const [Shadow(color: Color(0x80000000), blurRadius: 24)],
    ),
  );
});

/// Portrait stylisé : silhouette douce sur fond coloré.
Future<Uint8List> renderPortrait(double hue) => _render(400, 400, (c, s) {
  final base = HSLColor.fromAHSL(1, hue, 0.45, 0.32).toColor();
  final lightColor = HSLColor.fromAHSL(1, (hue + 25) % 360, 0.55, 0.62).toColor();
  c.drawRect(
    Offset.zero & s,
    Paint()..shader = ui.Gradient.radial(Offset(s.width * 0.3, s.height * 0.2), s.width, [lightColor, base]),
  );
  final skin = Paint()..color = const Color(0xFF0E0C12).withValues(alpha: 0.82);
  c.drawCircle(Offset(s.width / 2, s.height * 0.42), s.width * 0.17, skin);
  c.drawOval(Rect.fromCenter(center: Offset(s.width / 2, s.height * 0.98), width: s.width * 0.78, height: s.height * 0.62), skin);
});

/// Vignette de bibliothèque : paysage + nom.
Future<Uint8List> renderLibrary(Scene scene, String name) => _render(800, 450, (c, s) {
  paintScene(c, s, scene, variant: 11);
  c.drawRect(Offset.zero & s, Paint()..color = const Color(0x66000000));
  _text(
    c,
    name.toUpperCase(),
    center: s.center(Offset.zero),
    maxWidth: s.width * 0.9,
    style: const TextStyle(fontFamily: fontSans, fontSize: 56, fontWeight: FontWeight.w800, letterSpacing: 10, color: Color(0xFFFFFFFF)),
  );
});
