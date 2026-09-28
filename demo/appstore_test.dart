import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo_fonts.dart';

/// Captures « App Store » (iPhone 6,9 pouces, 1320 × 2868) : titre court en haut,
/// fond noir à peine teinté, l'app réelle dans un téléphone.
///
///   flutter test demo/appstore_test.dart   →  build/demo/appstore/NN_nom.png
const _w = 1320.0;
const _h = 2868.0;

class Panel {
  const Panel(this.name, this.shots, this.title, this.sub, this.tint, {this.landscape = false});

  final String name;
  final List<String> shots;
  final String title;
  final String sub;
  final Color tint;
  final bool landscape;
}

const panels = [
  Panel(
    'accueil',
    ['home'],
    'Votre Jellyfin,\nen version cinéma.',
    'Un accueil immersif, à la une.',
    Color(0xFFE0855A),
  ),
  Panel(
    'fiche',
    ['details'],
    'Chaque film\na sa fiche.',
    '4K · Dolby Vision · Atmos, en un coup d’œil.',
    Color(0xFFD9774A),
  ),
  Panel(
    'series',
    ['series'],
    'Reprenez là où\nvous en étiez.',
    'Saisons, épisodes et suivi de lecture.',
    Color(0xFF3FC9A8),
  ),
  Panel(
    'lecteur',
    ['player', 'player_menu'],
    'Un lecteur\nqui s’efface.',
    'Le bon moteur pour chaque fichier.',
    Color(0xFF4DA3FF),
    landscape: true,
  ),
  Panel('hors-ligne', ['downloads'], 'Même sans\nréseau.', 'Films et saisons téléchargés.', Color(0xFF6C8CFF)),
];

void main() {
  testWidgets('captures App Store', (tester) async {
    await tester.runAsync(() async {
      await loadDemoFonts();
      final out = Directory('build/demo/appstore')..createSync(recursive: true);
      for (final (i, p) in panels.indexed) {
        final shots = [for (final s in p.shots) await _decode(File('build/demo/shots/$s.png').readAsBytesSync())];
        final recorder = ui.PictureRecorder();
        _paint(Canvas(recorder), p, shots);
        final image = await recorder.endRecording().toImage(_w.toInt(), _h.toInt());
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        File('${out.path}/${(i + 1).toString().padLeft(2, '0')}_${p.name}.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      }
    });
  }, timeout: const Timeout(Duration(minutes: 10)));
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

void _paint(Canvas c, Panel p, List<ui.Image> shots) {
  c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), Paint()..color = const Color(0xFF000000));
  final glow = Offset(_w / 2, p.landscape ? 1750 : 1900);
  c.drawCircle(
    glow,
    1300,
    Paint()..shader = ui.Gradient.radial(glow, 1300, [p.tint.withValues(alpha: 0.22), p.tint.withValues(alpha: 0)]),
  );

  // Titre et sous-titre, centrés.
  final title = TextPainter(
    text: TextSpan(
      text: p.title,
      style: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 112,
        fontWeight: FontWeight.w700,
        height: 1.06,
        letterSpacing: -3,
        color: Color(0xFFF5F5F7),
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout(maxWidth: _w - 160);
  title.paint(c, Offset((_w - title.width) / 2, 190));
  final sub = TextPainter(
    text: TextSpan(
      text: p.sub,
      style: const TextStyle(fontFamily: 'Roboto', fontSize: 46, height: 1.3, color: Color(0xFF8E8E96)),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout(maxWidth: _w - 200);
  sub.paint(c, Offset((_w - sub.width) / 2, 190 + title.height + 40));

  if (p.landscape) {
    // Deux téléphones couchés, l'un sous l'autre.
    const screenW = 1160.0;
    const gap = 140.0;
    final heights = [for (final s in shots) screenW * s.height / s.width];
    var y = 820 + (_h - 820 - heights.fold<double>(0, (a, b) => a + b) - gap * (shots.length - 1)) / 2;
    for (final (i, shot) in shots.indexed) {
      _phone(c, Rect.fromLTWH((_w - screenW) / 2, y, screenW, heights[i]), shot);
      y += heights[i] + gap;
    }
    return;
  }
  const screenW = 1000.0;
  final shot = shots.single;
  final h = screenW * shot.height / shot.width;
  _phone(c, Rect.fromLTWH((_w - screenW) / 2, 620, screenW, h), shot);
}

void _phone(Canvas c, Rect rect, ui.Image image) {
  const bezel = 24.0;
  final radius = rect.shortestSide * 0.135;
  final body = RRect.fromRectAndRadius(rect.inflate(bezel), Radius.circular(radius + bezel));
  c.drawRRect(
    body.shift(const Offset(0, 50)),
    Paint()
      ..color = const Color(0xCC000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80),
  );
  c.drawRRect(body, Paint()..color = const Color(0xFF141416));
  c.drawRRect(
    body,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..shader = ui.Gradient.linear(body.outerRect.topCenter, body.outerRect.bottomCenter, [
        const Color(0xFF6A6A72),
        const Color(0xFF2A2A2E),
      ]),
  );
  c.save();
  c.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
  c.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    rect,
    Paint()..filterQuality = FilterQuality.high,
  );
  c.restore();
}
