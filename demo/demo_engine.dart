import 'dart:async';

import 'package:flutter/material.dart';
import 'package:optifin/features/player/domain/playback_engine.dart';

/// Moteur de démo : pas de vraie vidéo, l'illustration de l'épisode défile
/// lentement (effet Ken Burns) ; la position avance avec l'horloge des captures.
class DemoEngine implements PlaybackEngine {
  DemoEngine(this.imageFor, {required this.durationOf, this.name = 'AVPlayer'});

  /// Durée de l'élément lu.
  final Duration Function(String itemId) durationOf;

  /// Illustration de l'élément lu (id extrait de l'URL du flux).
  final ImageProvider Function(String itemId) imageFor;

  @override
  final String name;

  final _snapshots = StreamController<PlayerSnapshot>.broadcast();
  final _events = StreamController<PlaybackEvent>.broadcast();
  PlayerSnapshot _snapshot = const PlayerSnapshot();
  Timer? _clock;
  String _itemId = '';

  @override
  EngineCapabilities get capabilities => const EngineCapabilities(
    pictureInPicture: true,
    hdr: true,
    dolbyVision: true,
    subtitleStyling: true,
    subtitleDelay: true,
    embeddedSubtitles: false,
  );

  @override
  PlayerSnapshot get snapshot => _snapshot;

  @override
  Stream<PlayerSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<PlaybackEvent> get events => _events.stream;

  void _emit(PlayerSnapshot s) {
    _snapshot = s;
    if (!_snapshots.isClosed) _snapshots.add(s);
  }

  /// Saut direct (scénario de la démo : arriver au générique).
  void jumpTo(Duration position) => _emit(_snapshot.copyWith(position: position));

  @override
  Future<void> open(EngineMedia media) async {
    final seg = media.url.pathSegments;
    final i = seg.indexOf('Videos');
    _itemId = i >= 0 && i + 1 < seg.length ? seg[i + 1] : '';
    _emit(
      PlayerSnapshot(
        status: PlaybackStatus.ready,
        playing: true,
        position: media.start,
        duration: durationOf(_itemId),
        buffered: media.start + const Duration(minutes: 3),
        videoSize: const Size(3840, 2160),
        droppedFrames: 0,
      ),
    );
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!_snapshot.playing) return;
      final p = _snapshot.position + const Duration(milliseconds: 100);
      _emit(_snapshot.copyWith(position: p, buffered: p + const Duration(minutes: 3)));
    });
  }

  @override
  Future<void> play() async => _emit(_snapshot.copyWith(playing: true));

  @override
  Future<void> pause() async => _emit(_snapshot.copyWith(playing: false));

  @override
  Future<void> seek(Duration position) async => _emit(_snapshot.copyWith(position: position));

  @override
  Future<void> setRate(double rate) async => _emit(_snapshot.copyWith(rate: rate));

  @override
  Future<void> selectAudio(int? ordinal) async {}

  @override
  Future<void> selectSubtitle(int? ordinal) async {}

  @override
  Future<void> addExternalSubtitle(Uri url, {String? title, String? language}) async {}

  @override
  Future<void> setSubtitleStyle(SubtitleStyle style) async {}

  @override
  Future<void> setSubtitleDelay(Duration delay) async {}

  @override
  Future<void> setAudioDelay(Duration delay) async {}

  @override
  Future<bool> enterPictureInPicture() async => false;

  @override
  Widget buildView({BoxFit fit = BoxFit.contain}) => _KenBurns(image: imageFor(_itemId));

  @override
  Future<void> dispose() async {
    _clock?.cancel();
    await _snapshots.close();
    await _events.close();
  }
}

class _KenBurns extends StatefulWidget {
  const _KenBurns({required this.image});

  final ImageProvider image;

  @override
  State<_KenBurns> createState() => _KenBurnsState();
}

class _KenBurnsState extends State<_KenBurns> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 30))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.scale(
        scale: 1.02 + _c.value * 0.1,
        alignment: Alignment(-0.3 + _c.value * 0.6, 0),
        child: child,
      ),
      child: SizedBox.expand(
        child: Image(image: widget.image, fit: BoxFit.cover, gaplessPlayback: true),
      ),
    ),
  );
}
