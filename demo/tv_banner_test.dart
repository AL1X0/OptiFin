import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo_fonts.dart';

/// Bannière du lanceur Android TV (320 × 180 px, drawable-xhdpi) : logo et nom sur fond sombre.
///
///   flutter test demo/tv_banner_test.dart   →  android/app/src/main/res/drawable-xhdpi/tv_banner.png
void main() {
  testWidgets('bannière Android TV', (tester) async {
    await tester.runAsync(() async {
      await loadDemoFonts();
      const w = 320.0;
      const h = 180.0;
      final logo = await _decode(File('assets/branding/icon_1024.png').readAsBytesSync());
      final recorder = ui.PictureRecorder();
      final c = Canvas(recorder);
      c.drawRect(
        const Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, const Offset(w, h), [
            const Color(0xFF0B0B10),
            const Color(0xFF12182A),
          ]),
      );
      c.drawCircle(
        const Offset(78, 90),
        120,
        Paint()
          ..shader = ui.Gradient.radial(const Offset(78, 90), 120, [const Color(0x334DA3FF), const Color(0x004DA3FF)]),
      );
      const logoRect = Rect.fromLTWH(34, 46, 88, 88);
      c.save();
      c.clipRRect(RRect.fromRectAndRadius(logoRect, const Radius.circular(20)));
      c.drawImageRect(
        logo,
        Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
        logoRect,
        Paint()..filterQuality = FilterQuality.high,
      );
      c.restore();
      final title = TextPainter(
        text: const TextSpan(
          text: 'OptiFin',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 44,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
            color: Color(0xFFF5F5F7),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      title.paint(c, Offset(140, (h - title.height) / 2 - 6));
      final sub = TextPainter(
        text: const TextSpan(
          text: 'Jellyfin',
          style: TextStyle(fontFamily: 'Roboto', fontSize: 17, letterSpacing: 2, color: Color(0xFF8E8E96)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      sub.paint(c, Offset(142, (h + title.height) / 2 - 8));
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
