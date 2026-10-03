import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo_fonts.dart';

/// Bannière du lanceur Android TV (320 × 180 px, drawable-xhdpi) : logo et nom sur fond noir.
///
///   flutter test demo/tv_banner_test.dart   →  android/app/src/main/res/drawable-xhdpi/tv_banner.png
void main() {
  testWidgets('bannière Android TV', (tester) async {
    await tester.runAsync(() async {
      await loadDemoFonts();
      const w = 320.0;
      const h = 180.0;
      // Logo seul (sans carré de fond) sur noir pur, puis le nom : groupe centré.
      final logo = await _decode(File('assets/branding/splash_logo_black.png').readAsBytesSync());
      final recorder = ui.PictureRecorder();
      final c = Canvas(recorder);
      c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF000000));
      final title = TextPainter(
        text: const TextSpan(
          text: 'OptiFin',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 50,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
            color: Color(0xFFF5F5F7),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      const logoSize = 84.0;
      const gap = 12.0;
      final left = (w - logoSize - gap - title.width) / 2;
      // Le logo occupe le centre de l'image source (≈ 340 × 380 px sur 1024).
      final scale = logo.width / 1024;
      c.drawImageRect(
        logo,
        Rect.fromLTWH(300 * scale, 300 * scale, 424 * scale, 424 * scale),
        Rect.fromLTWH(left, (h - logoSize) / 2, logoSize, logoSize),
        Paint()..filterQuality = FilterQuality.high,
      );
      title.paint(c, Offset(left + logoSize + gap, (h - title.height) / 2));
      final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('android/app/src/main/res/drawable-xhdpi/tv_banner.png')..createSync(recursive: true);
      out.writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}
