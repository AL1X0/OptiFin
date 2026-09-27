import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:jellyfin_api/jellyfin_api.dart' hide PlayMethod;
import 'package:optifin/core/media/media_item.dart';
import 'package:optifin/core/media/media_repository.dart';
import 'package:optifin/features/player/data/playback_repository.dart';
import 'package:optifin/features/player/domain/playback_engine.dart';
import 'package:optifin/features/player/domain/playback_plan.dart';
import 'package:optifin/features/player/domain/playback_reporter.dart';

/// Moteur factice : enregistre les commandes, émet des états à la demande.
class FakeEngine implements PlaybackEngine {
  FakeEngine({this.capabilities = const EngineCapabilities(subtitleStyling: true)});

  @override
  final EngineCapabilities capabilities;

  final opened = <EngineMedia>[];
  final commands = <String>[];
  final _snapshots = StreamController<PlayerSnapshot>.broadcast();
  final _events = StreamController<PlaybackEvent>.broadcast();
  PlayerSnapshot _snapshot = const PlayerSnapshot();
  bool disposed = false;

  void emit(PlayerSnapshot s) {
    _snapshot = s;
    _snapshots.add(s);
  }

  void fire(PlaybackEvent e) => _events.add(e);

  @override
  String get name => 'fake';

  @override
  PlayerSnapshot get snapshot => _snapshot;

  @override
  Stream<PlayerSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<PlaybackEvent> get events => _events.stream;

  @override
  Future<void> open(EngineMedia media) async {
    opened.add(media);
    emit(PlayerSnapshot(status: PlaybackStatus.ready, playing: true, position: media.start, duration: const Duration(hours: 2)));
  }

  @override
  Future<void> play() async {
    commands.add('play');
    emit(_snapshot.copyWith(playing: true));
  }

  @override
  Future<void> pause() async {
    commands.add('pause');
    emit(_snapshot.copyWith(playing: false));
  }

  @override
  Future<void> seek(Duration position) async {
    commands.add('seek:${position.inSeconds}');
    emit(_snapshot.copyWith(position: position));
  }

  @override
  Future<void> setRate(double rate) async => commands.add('rate:$rate');

  @override
  Future<void> selectAudio(int? ordinal) async => commands.add('audio:$ordinal');

  @override
  Future<void> selectSubtitle(int? ordinal) async => commands.add('sub:$ordinal');

  @override
  Future<void> addExternalSubtitle(Uri url, {String? title, String? language}) async => commands.add('extsub:$url');

  @override
  Future<void> setSubtitleStyle(SubtitleStyle style) async => commands.add('style:${style.scale}');

  @override
  Future<void> setSubtitleDelay(Duration delay) async {}

  @override
  Future<void> setAudioDelay(Duration delay) async {}

  @override
  Widget buildView({BoxFit fit = BoxFit.contain}) => const SizedBox.expand(key: ValueKey('video'));

  @override
  Future<void> dispose() async {
    disposed = true;
    await _snapshots.close();
    await _events.close();
  }
}

/// Dépôt de lecture factice : plan configurable, rapports enregistrés.
class FakePlaybackRepository extends PlaybackRepository {
  FakePlaybackRepository(this.planFor) : super(JellyfinClient(Dio()), userId: 'u', baseUrl: Uri.parse('http://s/jf'));

  final PlaybackPlan Function({int? audioIndex, int? subtitleIndex}) planFor;
  final prepareCalls = <(int?, int?)>[];
  final reports = <String>[];
  Object? prepareError;

  @override
  Future<PlaybackPlan> prepare({
    required String itemId,
    Duration start = Duration.zero,
    int? audioIndex,
    int? subtitleIndex,
    String? mediaSourceId,
    Map<String, Object?>? deviceProfile,
    int maxStreamingBitrate = 0,
  }) async {
    prepareCalls.add((audioIndex, subtitleIndex));
    if (prepareError != null) throw prepareError!;
    return planFor(audioIndex: audioIndex, subtitleIndex: subtitleIndex);
  }

  @override
  Future<void> start(PlaybackReport report) async => reports.add('start@${report.position.inSeconds}');

  @override
  Future<void> progress(PlaybackReport report) async =>
      reports.add('progress@${report.position.inSeconds}${report.isPaused ? ' paused' : ''}');

  @override
  Future<void> stopped(PlaybackReport report) async => reports.add('stopped@${report.position.inSeconds}');
}

class FakeMediaRepository extends MediaRepository {
  FakeMediaRepository(this.value) : super(JellyfinClient(Dio()), 'u');

  final MediaItem value;

  @override
  Future<MediaItem> item(String id) async => value;
}

const audioFr = MediaTrack(index: 1, type: TrackType.audio, label: 'Français 5.1', language: 'fre', codec: 'eac3');
const audioEn = MediaTrack(index: 2, type: TrackType.audio, label: 'English 7.1', language: 'eng', codec: 'truehd');
const subFr = MediaTrack(index: 3, type: TrackType.subtitle, label: 'Français (ASS)', codec: 'ass');
const subPgs = MediaTrack(index: 4, type: TrackType.subtitle, label: 'English (PGS)', codec: 'pgssub', isTextBased: false);
const subExt = MediaTrack(
  index: 5,
  type: TrackType.subtitle,
  label: 'Externe SRT',
  codec: 'srt',
  isExternal: true,
  deliveryUrl: '/Videos/m/src/Subtitles/5/0/Stream.srt',
);

PlaybackPlan plan({PlayMethod method = PlayMethod.directPlay, int? audioIndex = 1, int? subtitleIndex}) => PlaybackPlan(
      itemId: 'm',
      mediaSourceId: 'src',
      playSessionId: 'ps',
      method: method,
      streamUrl: Uri.parse('http://s/jf/Videos/m/stream?static=true'),
      audioTracks: const [audioFr, audioEn],
      subtitleTracks: const [subFr, subPgs, subExt],
      audioIndex: audioIndex,
      subtitleIndex: subtitleIndex,
    );
