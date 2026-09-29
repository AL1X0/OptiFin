import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'demo_artwork.dart';
import 'demo_fonts.dart';
import 'demo_library.dart';

/// Aperçu des illustrations générées (contrôle visuel) : build/demo/artwork/.
void main() {
  testWidgets('aperçu des illustrations', (tester) async {
    await tester.runAsync(() async {
      await loadDemoFonts();
      final out = Directory('build/demo/artwork')..createSync(recursive: true);
      for (final m in [...movies, ...series]) {
        File('${out.path}/${m.id}_backdrop.png')
            .writeAsBytesSync(await renderBackdrop(m.scene, variant: m.variant, width: 800));
        File('${out.path}/${m.id}_poster.png').writeAsBytesSync(
          await renderPoster(m.scene, m.name, tagline: m.tagline, variant: m.variant, series: m.type == 'Series'),
        );
        File('${out.path}/${m.id}_logo.png').writeAsBytesSync(await renderLogo(m.scene, m.name));
      }
      File('${out.path}/portrait.png').writeAsBytesSync(await renderPortrait(200));
    });
  });
}
