import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_api/jellyfin_api.dart' hide PlayMethod;
import 'package:optifin/core/network/dio_factory.dart';
import 'package:optifin/core/network/jellyfin_auth.dart';
import 'package:optifin/features/player/data/device_profiles.dart';
import 'package:optifin/features/player/data/playback_repository.dart';
import 'package:optifin/features/player/domain/playback_plan.dart';
import 'package:optifin/features/player/domain/playback_reporter.dart';

import '../../helpers/fake_http.dart';
import 'fakes.dart';

Map<String, Object?> stream(int index, String type, {String? codec, String? lang, String? title, bool external = false, bool text = true, String? url}) => {
      'Index': index,
      'Type': type,
      'Codec': ?codec,
      'Language': ?lang,
      'DisplayTitle': ?title,
      'IsExternal': external,
      'IsTextSubtitleStream': text,
      'DeliveryUrl': ?url,
    };

PlaybackInfoResponse response({
  bool directPlay = true,
  bool directStream = false,
  String? transcodingUrl,
  int? defaultAudio = 1,
  int? defaultSub,
  String? errorCode,
  bool noSources = false,
}) =>
    PlaybackInfoResponse.fromJson({
      'PlaySessionId': 'ps1',
      'ErrorCode': ?errorCode,
      'MediaSources': noSources
          ? <Object?>[]
          : [
              {
                'Id': 'src1',
                'ETag': 'etag',
                'Container': 'mkv',
                'Bitrate': 60000000,
                'RunTimeTicks': 72000000000,
                'SupportsDirectPlay': directPlay,
                'SupportsDirectStream': directStream,
                'TranscodingUrl': ?transcodingUrl,
                'DefaultAudioStreamIndex': ?defaultAudio,
                'DefaultSubtitleStreamIndex': ?defaultSub,
                'MediaStreams': [
                  stream(0, 'Video', codec: 'hevc'),
                  stream(2, 'Audio', codec: 'truehd', lang: 'eng', title: 'English TrueHD 7.1'),
                  stream(1, 'Audio', codec: 'eac3', lang: 'fre'),
                  stream(3, 'Subtitle', codec: 'PGSSUB', lang: 'fre', text: false),
                  stream(4, 'Subtitle', codec: 'srt', external: true, url: '/Videos/x/src1/Subtitles/4/0/Stream.srt?api_key=k'),
                ],
              },
            ],
    });

void main() {
  final base = Uri.parse('https://media.example.fr/jellyfin');

  group('planFromResponse', () {
    test('Direct Play : URL statique, sous-chemin conservé, pistes triées', () {
      final p = PlaybackRepository.planFromResponse(response(), itemId: 'x', baseUrl: base);
      expect(p.method, PlayMethod.directPlay);
      expect(p.streamUrl.path, '/jellyfin/Videos/x/stream');
      expect(p.streamUrl.queryParameters, {'static': 'true', 'mediaSourceId': 'src1', 'playSessionId': 'ps1', 'tag': 'etag'});
      expect(p.streamUrl.queryParameters.keys, isNot(contains('api_key')), reason: 'token passé en en-tête');
      expect(p.audioTracks.map((t) => t.index), [1, 2]);
      expect(p.audioTracks.first.label, 'FRE · EAC3', reason: 'libellé de repli sans DisplayTitle');
      expect(p.audioTracks.last.label, 'English TrueHD 7.1');
      expect(p.subtitleTracks.first.isBitmap, isTrue);
      expect(p.subtitleTracks.first.codec, 'pgssub');
      expect(p.audioIndex, 1);
      expect(p.subtitleIndex, isNull);
      expect(p.runtime, const Duration(hours: 2));
      expect(p.canSwitchTracksLocally, isTrue);
    });

    test('Transcodage : URL serveur résolue avec sa query', () {
      final p = PlaybackRepository.planFromResponse(
        response(directPlay: false, transcodingUrl: '/videos/x/master.m3u8?MediaSourceId=src1&ApiKey=abc&VideoCodec=h264'),
        itemId: 'x',
        baseUrl: base,
      );
      expect(p.method, PlayMethod.transcode);
      expect(p.streamUrl.toString(), startsWith('https://media.example.fr/jellyfin/videos/x/master.m3u8?'));
      expect(p.streamUrl.queryParameters['VideoCodec'], 'h264');
      expect(p.canSwitchTracksLocally, isFalse);
    });

    test('Direct Stream (remux)', () {
      final p = PlaybackRepository.planFromResponse(
        response(directPlay: false, directStream: true, transcodingUrl: 'videos/x/master.m3u8?a=1'),
        itemId: 'x',
        baseUrl: base,
      );
      expect(p.method, PlayMethod.directStream);
    });

    test('sous-titre par défaut -1 ou inconnu → aucun ; demande explicite prioritaire', () {
      expect(PlaybackRepository.planFromResponse(response(defaultSub: -1), itemId: 'x', baseUrl: base).subtitleIndex, isNull);
      expect(PlaybackRepository.planFromResponse(response(defaultSub: 99), itemId: 'x', baseUrl: base).subtitleIndex, isNull);
      expect(PlaybackRepository.planFromResponse(response(defaultSub: 3), itemId: 'x', baseUrl: base).subtitleIndex, 3);
      final p = PlaybackRepository.planFromResponse(response(), itemId: 'x', baseUrl: base, requestedAudio: 2, requestedSubtitle: 4);
      expect((p.audioIndex, p.subtitleIndex), (2, 4));
    });

    test('refus serveur → PlaybackDeniedFailure avec message clair', () {
      expect(
        () => PlaybackRepository.planFromResponse(response(errorCode: 'NotAllowed'), itemId: 'x', baseUrl: base),
        throwsA(isA<PlaybackDeniedFailure>().having((f) => f.userMessage, 'message', contains('pas autorisée'))),
      );
      expect(
        () => PlaybackRepository.planFromResponse(response(noSources: true), itemId: 'x', baseUrl: base),
        throwsA(isA<PlaybackDeniedFailure>()),
      );
      expect(
        () => PlaybackRepository.planFromResponse(response(directPlay: false), itemId: 'x', baseUrl: base),
        throwsA(isA<PlaybackDeniedFailure>()),
        reason: 'ni lecture directe ni URL de transcodage',
      );
    });
  });

  group('embeddedOrdinal', () {
    test('position parmi les pistes intégrées du même type', () {
      final tracks = [subExt, subPgs, subFr]; // désordonnées, avec une externe
      expect(embeddedOrdinal(tracks, 3), 0);
      expect(embeddedOrdinal(tracks, 4), 1);
      expect(embeddedOrdinal(tracks, 5), isNull, reason: 'externe : absente du fichier');
      expect(embeddedOrdinal(tracks, null), isNull);
      expect(embeddedOrdinal(tracks, 42), isNull);
    });
  });

  group('prepare (requête)', () {
    test('envoie le profil mpv et les options de lecture dans le corps', () async {
      final adapter = FakeHttpAdapter({'POST http://s/Items/x/PlaybackInfo': FakeResponse(200, response().toJson())});
      final dio = createJellyfinDio(
        baseUrl: Uri.parse('http://s'),
        identity: const ClientIdentity(clientName: 'c', deviceName: 'd', deviceId: 'i', version: '1'),
        tokenProvider: () => 't',
      );
      dio.httpClientAdapter = adapter;
      final repo = PlaybackRepository(JellyfinClient(dio), userId: 'u', baseUrl: Uri.parse('http://s'));

      final p = await repo.prepare(itemId: 'x', audioIndex: 2);
      expect(p.audioIndex, 2);
      // Corps tel qu'envoyé sur le réseau.
      final body = jsonDecode(jsonEncode(adapter.requests.single.data)) as Map<String, dynamic>;
      expect(body['UserId'], 'u');
      expect(body['AudioStreamIndex'], 2);
      expect(body['EnableDirectPlay'], isTrue);
      final profile = body['DeviceProfile'] as Map<String, dynamic>;
      expect((profile['DirectPlayProfiles'] as List<dynamic>).first['Type'], 'Video');
      expect(profile['Name'], 'OptiFin (mpv)');
      expect(profile['MaxStreamingBitrate'], defaultMaxStreamingBitrate);
    });

    // Régression : le serveur (.NET) répond 400 si un champ non-nullable reçoit null
    // (ex. TranscodingProfile.TranscodeSeekInfo) → échec de TOUTES les lectures.
    test('aucune valeur null dans les corps envoyés (PlaybackInfo et rapports)', () async {
      final adapter = FakeHttpAdapter({
        'POST http://s/Items/x/PlaybackInfo': FakeResponse(200, response().toJson()),
        'POST http://s/Sessions/Playing': const FakeResponse(204, ''),
        'POST http://s/Sessions/Playing/Progress': const FakeResponse(204, ''),
        'POST http://s/Sessions/Playing/Stopped': const FakeResponse(204, ''),
      });
      final dio = createJellyfinDio(
        baseUrl: Uri.parse('http://s'),
        identity: const ClientIdentity(clientName: 'c', deviceName: 'd', deviceId: 'i', version: '1'),
        tokenProvider: () => 't',
      );
      dio.httpClientAdapter = adapter;
      final repo = PlaybackRepository(JellyfinClient(dio), userId: 'u', baseUrl: Uri.parse('http://s'));
      final p = await repo.prepare(itemId: 'x');
      const report = PlaybackReport(itemId: 'x', mediaSourceId: 'src1', playSessionId: null, method: PlayMethod.directPlay, position: Duration(seconds: 5));
      await repo.start(report);
      await repo.progress(report);
      await repo.stopped(report);
      expect(p.method, PlayMethod.directPlay);

      List<String> nullPaths(Object? node, String path) => switch (node) {
            null => [path],
            Map<String, dynamic>() => [for (final e in node.entries) ...nullPaths(e.value, '$path.${e.key}')],
            List<dynamic>() => [for (final (i, v) in node.indexed) ...nullPaths(v, '$path[$i]')],
            _ => const [],
          };
      for (final r in adapter.requests) {
        final body = jsonDecode(jsonEncode(r.data));
        expect(nullPaths(body, r.path), isEmpty, reason: 'corps de ${r.path}');
      }
      expect(adapter.requests, hasLength(4));
    });
  });

  test('profil mpv : Direct Play large, sous-titres image jamais extraits', () {
    final profile = DeviceProfile.fromJson(mpvDeviceProfile());
    final video = profile.directPlayProfiles!.firstWhere((p) => p.type == DirectPlayProfileType.video);
    expect(video.container, contains('mkv'));
    expect(video.videoCodec, isNull, reason: 'aucune restriction de codec');
    final pgs = profile.subtitleProfiles!.where((s) => s.format == 'pgssub').map((s) => s.method).toSet();
    expect(pgs, {SubtitleProfileMethod.embed, SubtitleProfileMethod.encode});
    expect(profile.transcodingProfiles!.first.protocol, TranscodingProfileProtocol.hls);
  });

  group('PlaybackReporter', () {
    late FakePlaybackRepository sink;
    setUp(() => sink = FakePlaybackRepository(plan));

    test('start, progress périodique, pause immédiate, seek, stop final', () {
      fakeAsync((async) {
        final r = PlaybackReporter(sink, interval: const Duration(seconds: 10));
        r.started(plan(), position: const Duration(seconds: 30));
        async.flushMicrotasks();
        r.update(position: const Duration(seconds: 35), paused: false);
        async.elapse(const Duration(seconds: 10));
        r.update(position: const Duration(seconds: 42), paused: true);
        r.update(position: const Duration(seconds: 42), paused: true); // pas de doublon
        r.seeked(const Duration(seconds: 100));
        async.flushMicrotasks();
        r.stop();
        async.elapse(const Duration(seconds: 30)); // plus aucun tick après stop
        expect(sink.reports, [
          'start@30',
          'progress@35',
          'progress@42 paused',
          'progress@100 paused',
          'stopped@100',
        ]);
      });
    });

    test('stop idempotent, erreurs réseau avalées', () async {
      final failing = _FailingSink();
      final r = PlaybackReporter(failing)..started(plan());
      await r.stop();
      await r.stop();
      expect(failing.calls, 2, reason: 'start + un seul stopped');
      expect(r.isActive, isFalse);
    });
  });
}

class _FailingSink implements PlaybackReportSink {
  int calls = 0;

  Future<void> _fail() async {
    calls++;
    throw Exception('réseau');
  }

  @override
  Future<void> progress(PlaybackReport report) => _fail();

  @override
  Future<void> start(PlaybackReport report) => _fail();

  @override
  Future<void> stopped(PlaybackReport report) => _fail();
}
