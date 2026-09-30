import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:optifin_native_player/optifin_native_player.dart' show NativePlayers;
import 'package:optifin/features/player/data/engines/windows_mpv_engine.dart';
import 'package:optifin/features/player/domain/playback_engine.dart';

/// Moteur libmpv natif de Windows, dans l'appli Windows réelle (fenêtre, plugin, libmpv).
///
///   flutter test integration_test/windows_mpv_test.dart -d windows
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('lecture, position, pause, recherche, fin', (tester) async {
    await tester.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: SizedBox.expand()));
    final file = File('${Directory.systemTemp.path}/optifin_mire.avi');
    file.writeAsBytesSync(_avi(width: 320, height: 180, fps: 30, seconds: 4));

    final engine = await WindowsMpvEngine.create();
    final snapshots = <PlayerSnapshot>[];
    final events = <PlaybackEvent>[];
    engine.snapshots.listen(snapshots.add);
    engine.events.listen(events.add);

    Future<void> until(bool Function() ok, String what, {int seconds = 15}) async {
      final deadline = DateTime.now().add(Duration(seconds: seconds));
      while (!ok()) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Délai dépassé : $what (dernier état : ${_describe(engine.snapshot)})');
        }
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      }
    }

    await tester.runAsync(() => engine.open(EngineMedia(url: Uri.file(file.path), start: const Duration(seconds: 1))));
    await until(() => engine.snapshot.status == PlaybackStatus.ready, 'prêt');
    expect(engine.snapshot.duration.inMilliseconds, closeTo(4000, 100));
    await until(() => engine.snapshot.videoSize != null, 'taille de la vidéo');
    expect(engine.snapshot.videoSize, const Size(320, 180));
    await until(() => engine.snapshot.position > const Duration(milliseconds: 1400), 'lecture à partir de 1 s');
    expect(engine.snapshot.playing, isTrue);

    await tester.runAsync(engine.pause);
    await until(() => !engine.snapshot.playing, 'pause');
    await tester.runAsync(() => engine.seek(const Duration(milliseconds: 3000)));
    await until(
      () => (engine.snapshot.position - const Duration(seconds: 3)).abs() < const Duration(milliseconds: 150),
      'recherche',
    );
    await tester.runAsync(engine.play);
    await until(() => events.whereType<PlaybackCompleted>().isNotEmpty, 'fin de lecture');
    expect(engine.snapshot.status, PlaybackStatus.ended);

    await tester.runAsync(engine.dispose);
    file.deleteSync();
  });

  testWidgets('intégrations Windows : session multimédia, plein écran, veille', (tester) async {
    await tester.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: SizedBox.expand()));
    await tester.runAsync(() async {
      await NativePlayers.updateMediaSession(
        title: 'Les Marées d’Orion',
        subtitle: 'S1 · É2',
        playing: true,
        position: const Duration(minutes: 12),
        duration: const Duration(hours: 2),
        hasNext: true,
      );
      await NativePlayers.updateMediaSession(
        title: 'Les Marées d’Orion',
        playing: false,
        position: const Duration(minutes: 13),
        duration: const Duration(hours: 2),
      );
      await NativePlayers.clearMediaSession();
      await NativePlayers.keepAwake(true);
      await NativePlayers.keepAwake(false);
      await NativePlayers.setFullscreen(true);
      expect(await NativePlayers.isFullscreen(), isTrue);
      await NativePlayers.setFullscreen(false);
      expect(await NativePlayers.isFullscreen(), isFalse);
    });
  });

  testWidgets('fichier introuvable : échec au démarrage (déclenche le repli)', (tester) async {
    await tester.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: SizedBox.expand()));
    final engine = await WindowsMpvEngine.create();
    final events = <PlaybackEvent>[];
    engine.events.listen(events.add);
    await tester.runAsync(() => engine.open(EngineMedia(url: Uri.file('C:/introuvable/film.mkv'))));
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (events.isEmpty && DateTime.now().isBefore(deadline)) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    }
    final failure = events.whereType<PlaybackFailed>().single;
    expect(failure.duringStartup, isTrue);
    await tester.runAsync(engine.dispose);
  });
}

String _describe(PlayerSnapshot s) =>
    '${s.status.name}, position ${s.position}, durée ${s.duration}, lecture ${s.playing}, taille ${s.videoSize}';

/// AVI non compressé (RGB 24 bits) : barres de couleur qui défilent. Lu par mpv sans codec.
Uint8List _avi({required int width, required int height, required int fps, required int seconds}) {
  final frames = fps * seconds;
  final stride = (width * 3 + 3) & ~3;
  final frameSize = stride * height;
  final out = BytesBuilder();
  void u32(int v) => out.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) => out.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());
  void tag(String t) => out.add(t.codeUnits);

  const hdrlSize = 4 + (8 + 56) + (8 + 4 + (8 + 56) + (8 + 40));
  final moviSize = 4 + frames * (8 + frameSize);
  final idxSize = frames * 16;
  tag('RIFF');
  u32(4 + (8 + hdrlSize) + (8 + moviSize) + (8 + idxSize));
  tag('AVI ');
  tag('LIST');
  u32(hdrlSize);
  tag('hdrl');
  tag('avih');
  u32(56);
  u32(1000000 ~/ fps); // µs par image
  u32(frameSize * fps);
  u32(0);
  u32(0x10); // AVIF_HASINDEX
  u32(frames);
  u32(0);
  u32(1);
  u32(frameSize);
  u32(width);
  u32(height);
  for (var i = 0; i < 4; i++) {
    u32(0);
  }
  tag('LIST');
  u32(4 + (8 + 56) + (8 + 40));
  tag('strl');
  tag('strh');
  u32(56);
  tag('vids');
  tag('DIB ');
  u32(0);
  u16(0);
  u16(0);
  u32(0);
  u32(1); // échelle
  u32(fps); // débit
  u32(0);
  u32(frames);
  u32(frameSize);
  u32(0xFFFFFFFF);
  u32(0);
  u16(0);
  u16(0);
  u16(width);
  u16(height);
  tag('strf');
  u32(40);
  u32(40);
  u32(width);
  u32(height);
  u16(1);
  u16(24);
  u32(0); // BI_RGB
  u32(frameSize);
  for (var i = 0; i < 4; i++) {
    u32(0);
  }
  tag('LIST');
  u32(moviSize);
  tag('movi');
  const bars = [
    [255, 255, 255], [0, 255, 255], [255, 255, 0], [0, 255, 0], //
    [255, 0, 255], [0, 0, 255], [255, 0, 0], [0, 0, 0],
  ];
  for (var f = 0; f < frames; f++) {
    tag('00db');
    u32(frameSize);
    final frame = Uint8List(frameSize);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final c = bars[((x + f * 4) % width) * 8 ~/ width];
        final o = y * stride + x * 3;
        frame[o] = c[0];
        frame[o + 1] = c[1];
        frame[o + 2] = c[2];
      }
    }
    out.add(frame);
  }
  tag('idx1');
  u32(idxSize);
  for (var f = 0; f < frames; f++) {
    tag('00db');
    u32(0x10); // image clé
    u32(4 + f * (8 + frameSize));
    u32(frameSize);
  }
  return out.toBytes();
}
