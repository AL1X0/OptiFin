import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/core/design_system/design_system.dart';

void main() {
  testWidgets('verre natif : position, arrondi et visibilité transmis à la vue native', (tester) async {
    final sent = <List<Map<String, Object>>>[];
    final anchor = GlobalKey();
    var visible = true;
    late StateSetter setOuter;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: NativeGlassScope(
          anchorKey: anchor,
          onChanged: sent.add,
          child: StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return Stack(
                children: [
                  Positioned.fill(child: SizedBox.expand(key: anchor)),
                  Positioned(
                    left: 100,
                    top: 50,
                    child: Opacity(
                      opacity: visible ? 1 : 0,
                      child: const SizedBox(width: 44, height: 44, child: LiquidGlass.circle(child: SizedBox())),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    expect(sent.last, hasLength(1));
    final item = sent.last.single;
    expect([item['x'], item['y'], item['w'], item['h']], [100.0, 50.0, 44.0, 44.0]);
    expect(item['r'], 22.0);
    expect(item['visible'], isTrue);

    setOuter(() => visible = false);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(sent.last.single['visible'], isFalse);

    // Portée démontée : la vue native retire tout son verre.
    await tester.pumpWidget(const SizedBox());
    expect(sent.last, isEmpty);
  });
}
