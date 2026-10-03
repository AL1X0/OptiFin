import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/core/design_system/design_system.dart';
import 'package:optifin/features/player/domain/playback_engine.dart';
import 'package:optifin/features/player/presentation/player_controller.dart';
import 'package:optifin/features/player/presentation/player_tv_controls.dart';

import 'fakes.dart';

/// Lecteur TV à la télécommande : toutes les commandes s'atteignent aux flèches.
void main() {
  setUp(() => OFDevice.tv = true);
  tearDown(() => OFDevice.tv = false);

  String? focusedLabel() {
    final node = FocusManager.instance.primaryFocus;
    final widget = node?.context?.findAncestorWidgetOfExactType<TvControlButton>();
    return widget?.label ?? node?.debugLabel;
  }

  testWidgets('◀ ▶ parcourent toute la rangée de boutons, ▲ va à la barre de progression', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final play = FocusNode(debugLabel: 'lecture/pause');
    addTearDown(play.dispose);
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: OFTheme.dark(),
        home: Scaffold(
          backgroundColor: Colors.black,
          body: TvPlayerControls(
            snapshot: const PlayerSnapshot(
              duration: Duration(hours: 2),
              position: Duration(minutes: 30),
              playing: true,
              status: PlaybackStatus.ready,
            ),
            scrubbing: null,
            showSpinner: false,
            debug: false,
            ui: PlayerUiState(plan: plan()),
            engine: FakeEngine(),
            fit: BoxFit.contain,
            playFocus: play,
            onPlayPause: () => opened.add('lecture'),
            onSkip: (_) {},
            onScrubStart: (_) {},
            onScrub: (_) {},
            onScrubEnd: (_) {},
            onMenu: (page) => opened.add(page.name),
            onCycleFit: () => opened.add('format'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(focusedLabel(), 'Pause');

    final visited = <String?>[];
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      visited.add(focusedLabel());
    }
    expect(visited, containsAllInOrder(['+10 s', 'Sous-titres', 'Audio', 'Zoom', 'Réglages']));

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(opened.last, 'root');

    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
    }
    expect(focusedLabel(), '-10 s');
  });
}
