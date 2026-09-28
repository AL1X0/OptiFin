import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_api/jellyfin_api.dart' hide PlayMethod;
import 'package:optifin/features/player/data/device_profiles.dart';
import 'package:optifin/features/player/data/engines/native_engine.dart';
import 'package:optifin/features/player/data/engines/subtitle_overlay.dart';
import 'package:optifin/features/player/data/playback_preparer.dart';
import 'package:optifin/features/player/data/source_profile_mapper.dart';
import 'package:optifin/features/player/domain/device_capabilities.dart';
import 'package:optifin/features/player/domain/engine_selector.dart';
import 'package:optifin/features/player/domain/playback_engine.dart';
import 'package:optifin/features/player/domain/playback_plan.dart';
import 'package:optifin/features/player/domain/source_profile.dart';
import 'package:optifin/features/player/domain/subtitle_cues.dart';
import 'package:optifin/features/settings/domain/app_settings.dart';

import 'engine_matrix.dart';
import 'fakes.dart';

void main() {
  group('sourceProfileFrom (MediaSourceInfo → SourceProfile)', () {
    MediaSourceInfo source(List<Map<String, Object?>> streams, {String container = 'mkv'}) =>
        MediaSourceInfo.fromJson({'Id': 's', 'Container': container, 'Bitrate': 60000000, 'MediaStreams': streams});

    test('Dolby Vision 8.1 : couche de base HDR10, TrueHD Atmos, PGS', () {
      final p = sourceProfileFrom(
        source([
          {
            'Index': 0,
            'Type': 'Video',
            'Codec': 'hevc',
            'Width': 3840,
            'Height': 2160,
            'BitDepth': 10,
            'VideoRangeType': 'DOVIWithHDR10',
            'DvProfile': 8,
            'DvBlSignalCompatibilityId': 1,
          },
          {'Index': 1, 'Type': 'Audio', 'Codec': 'truehd', 'Profile': 'Dolby TrueHD + Dolby Atmos', 'Channels': 8},
          {'Index': 2, 'Type': 'Subtitle', 'Codec': 'PGSSUB', 'IsTextSubtitleStream': false},
          {'Index': 3, 'Type': 'Subtitle', 'Codec': 'subrip', 'IsTextSubtitleStream': true, 'IsExternal': true},
        ]),
      );
      expect(p.bitrate, 60000000);
      expect(p.video!.range, DynamicRange.dolbyVision);
      expect(p.video!.dvProfile, 8);
      expect(p.video!.dvBaseLayer, DynamicRange.hdr10);
      expect(p.video!.is10Bit, isTrue);
      expect(p.audio.single.codec, 'truehd');
      expect(p.audio.single.profile, 'TrueHD Atmos');
      expect(p.audio.single.atmos, isTrue);
      expect(p.subtitles.first.codec, 'pgssub');
      expect(p.subtitles.first.isBitmap, isTrue);
      expect(p.subtitles.last.codec, 'srt');
      expect(p.subtitles.last.isExternal, isTrue);
    });

    test('profil 5 : aucune couche de base ; DV invalide → HDR10', () {
      VideoInfo v(Map<String, Object?> extra) => sourceProfileFrom(
        source([
          {'Index': 0, 'Type': 'Video', 'Codec': 'hevc', ...extra},
        ]),
      ).video!;
      final p5 = v({'VideoRangeType': 'DOVI', 'DvProfile': 5, 'DvBlSignalCompatibilityId': 0});
      expect(p5.isDolbyVision, isTrue);
      expect(p5.dvBaseLayer, isNull);
      expect(v({'VideoRangeType': 'DOVIInvalid'}).range, DynamicRange.hdr10);
      expect(v({'VideoRangeType': 'DOVIWithHLG', 'DvProfile': 8}).dvBaseLayer, DynamicRange.hlg);
      expect(v({'VideoRangeType': 'HDR10Plus'}).range, DynamicRange.hdr10Plus);
    });

    test('serveur ancien sans VideoRangeType : fonction de transfert', () {
      VideoInfo v(Map<String, Object?> extra) => sourceProfileFrom(
        source([
          {'Index': 0, 'Type': 'Video', 'Codec': 'h265', ...extra},
        ]),
      ).video!;
      expect(v({'ColorTransfer': 'smpte2084'}).range, DynamicRange.hdr10);
      expect(v({'ColorTransfer': 'arib-std-b67'}).range, DynamicRange.hlg);
      expect(v({}).range, DynamicRange.sdr);
      expect(v({}).codec, 'hevc', reason: 'h265 normalisé');
      expect(v({'PixelFormat': 'yuv420p10le'}).bitDepth, 10);
    });

    test('codecs normalisés', () {
      expect(normalizeCodec('DCA'), 'dts');
      expect(normalizeCodec('E-AC-3'), 'eac3');
      expect(normalizeCodec('mlp'), 'truehd');
      expect(normalizeCodec('hdmv_pgs_subtitle'), 'pgssub');
      expect(normalizeCodec('pcm_s24le'), 'pcm');
      expect(normalizeCodec(null), '');
    });
  });

  group('DeviceCapabilities', () {
    test('lecture tolérante de la réponse du plugin', () {
      final caps = DeviceCapabilities.fromJson({
        'platform': 'ios',
        'model': 'iPhone16,1',
        'videoCodecs': ['h264', 'HEVC', 42],
        'ranges': ['hdr10', 'inconnu', 'dolbyVision'],
        'dolbyVisionProfiles': [5, 8, '7'],
        'maxWidth': 3840,
      });
      expect(caps.platform, DevicePlatform.ios);
      expect(caps.nativeAvailable, isTrue);
      expect(caps.videoCodecs, {'h264', 'hevc'});
      expect(caps.ranges, {DynamicRange.sdr, DynamicRange.hdr10, DynamicRange.dolbyVision});
      expect(caps.dolbyVisionProfiles, {5, 8});
      // Absents : valeurs prudentes de la plateforme.
      expect(caps.containers, {'mp4', 'm4v', 'mov'});
      expect(caps.audioCodecs, contains('eac3'));
    });

    test('plateforme inconnue → natif indisponible ; aller-retour JSON', () {
      expect(DeviceCapabilities.fromJson(const {}).nativeAvailable, isFalse);
      final back = DeviceCapabilities.tryParse(iphone15Pro.caps.toJsonString())!;
      expect(back.toJson(), iphone15Pro.caps.toJson());
      expect(DeviceCapabilities.tryParse('pas du json'), isNull);
      expect(iphone15Pro.caps.summary, contains('DV p5/8'));
    });
  });

  group('Profil natif', () {
    test('Dolby Vision annoncé seulement si l’appareil le décode', () {
      expect(nativeVideoRangeTypes(iphone15Pro.caps), containsAll(['DOVI', 'DOVIWithHDR10', 'HDR10', 'HLG']));
      final pixel = nativeVideoRangeTypes(pixel8.caps);
      expect(pixel, containsAll(['SDR', 'HDR10', 'HLG']));
      expect(pixel.where((r) => r.startsWith('DOVI') && r != 'DOVIInvalid'), isEmpty);
      expect(nativeVideoRangeTypes(androidBasic.caps), ['SDR']);
    });

    test('codecs, conteneurs, HLS fMP4 et sous-titres WebVTT', () {
      final p = nativeDeviceProfile(androidBasic.caps, maxStreamingBitrate: 20000000);
      final direct = (p['DirectPlayProfiles']! as List).first as Map<String, Object?>;
      expect(direct['Container'], contains('mkv'));
      expect(direct['VideoCodec'], 'hevc,h264');
      expect(direct['AudioCodec'], isNot(contains('ac3')));
      final hls = (p['TranscodingProfiles']! as List).first as Map<String, Object?>;
      expect((hls['Container'], hls['Protocol']), ('mp4', 'hls'));
      final hevc = (p['CodecProfiles']! as List).cast<Map<String, Object?>>().firstWhere((c) => c['Codec'] == 'hevc');
      expect(
        (hevc['Conditions']! as List).map((c) => (c as Map<String, Object?>)['Property']),
        contains('VideoBitDepth'),
      );
      final subs = (p['SubtitleProfiles']! as List).cast<Map<String, Object?>>();
      expect(subs.where((s) => s['Method'] == 'External').map((s) => s['Format']), ['vtt']);
      expect(subs.firstWhere((s) => s['Format'] == 'pgssub')['Method'], 'Encode');
    });

    test('accepté par le modèle Jellyfin sans valeur inconnue ni null', () {
      for (final d in devices) {
        final body = PlaybackInfoDto.fromJson({'UserId': 'u', 'DeviceProfile': nativeDeviceProfile(d.caps)}).toJson();
        final encoded = jsonEncode(body);
        expect(encoded, isNot(contains('null')), reason: d.id);
        expect(encoded, contains('"VideoRangeType"'), reason: d.id);
        expect(encoded, contains('"EqualsAny"'), reason: d.id);
      }
    });
  });

  group('Sous-titres (WebVTT / SRT)', () {
    test('WebVTT : en-tête, réglages de cue, balises, entités', () {
      const vtt = '''WEBVTT
Kind: captions

NOTE commentaire

1
00:00:01.000 --> 00:00:03.500 line:90% align:center
<i>Bonjour</i> &amp; bienvenue
<c.yellow>deuxième ligne</c>

00:01:02.250 --> 00:01:04.000
{\\an8}En haut
''';
      final cues = parseSubtitles(vtt);
      expect(cues, hasLength(2));
      expect(cues.first.start, const Duration(seconds: 1));
      expect(cues.first.end, const Duration(milliseconds: 3500));
      expect(cues.first.text, 'Bonjour & bienvenue\ndeuxième ligne');
      expect(cues.last.start, const Duration(minutes: 1, seconds: 2, milliseconds: 250));
      expect(cues.last.text, 'En haut');
    });

    test('SRT : virgule décimale, CRLF, BOM, blocs invalides ignorés', () {
      const srt =
          '﻿1\r\n00:00:05,100 --> 00:00:06,900\r\nPremière\r\n\r\n'
          '2\r\npas un horodatage\r\ntexte\r\n\r\n'
          '3\r\n00:00:08,000 --> 00:00:07,000\r\nfin avant début\r\n\r\n'
          '4\r\n01:00:00,5 --> 01:00:01,000\r\nHeure\r\n';
      final cues = parseSubtitles(srt);
      expect(cues.map((c) => c.text), ['Première', 'Heure']);
      expect(cues.last.start, const Duration(hours: 1, milliseconds: 500));
    });

    test('recherche des cues actives (bords, chevauchement, trous)', () {
      final track = CueTrack(const [
        SubtitleCue(Duration(seconds: 1), Duration(seconds: 3), 'A'),
        SubtitleCue(Duration(seconds: 2), Duration(seconds: 10), 'B longue'),
        SubtitleCue(Duration(seconds: 12), Duration(seconds: 13), 'C'),
      ]);
      expect(track.textAt(Duration.zero), isNull);
      expect(track.textAt(const Duration(seconds: 1)), 'A');
      expect(track.textAt(const Duration(milliseconds: 2500)), 'A\nB longue');
      expect(track.textAt(const Duration(seconds: 3)), 'B longue', reason: 'fin exclue');
      expect(track.textAt(const Duration(seconds: 11)), isNull);
      expect(track.textAt(const Duration(milliseconds: 12500)), 'C');
      expect(CueTrack(const []).textAt(Duration.zero), isNull);
    });

    test('horloge extrapolée entre deux mesures du moteur', () {
      const clock = PlaybackClock(Duration(seconds: 10), playing: true, rate: 1.5, at: 1000000);
      expect(clock.estimate(1200000), const Duration(seconds: 10, milliseconds: 300));
      expect(clock.estimate(900000), const Duration(seconds: 10), reason: 'jamais en arrière');
      expect(clock.estimate(60000000), const Duration(seconds: 12), reason: 'plafonné à 2 s sans nouvelle mesure');
      const paused = PlaybackClock(Duration(seconds: 10), at: 0);
      expect(paused.estimate(5000000), const Duration(seconds: 10));
    });

    testWidgets('overlay : texte au bon moment, style « bandeau »', (tester) async {
      final track = ValueNotifier<CueTrack?>(
        CueTrack(const [SubtitleCue(Duration(seconds: 1), Duration(seconds: 2), 'Salut')]),
      );
      final clock = ValueNotifier(PlaybackClock(Duration.zero, at: monotonicMicros()));
      final style = ValueNotifier(const SubtitleStyle(background: SubtitleBackground.box));
      final delay = ValueNotifier(Duration.zero);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SubtitleOverlay(track: track, clock: clock, style: style, delay: delay),
        ),
      );
      expect(find.text('Salut'), findsNothing);
      clock.value = PlaybackClock(const Duration(milliseconds: 1500), at: monotonicMicros());
      await tester.pump();
      expect(find.text('Salut'), findsOneWidget);
      expect(find.byType(DecoratedBox), findsOneWidget);
      // Décalage des sous-titres : +1 s → la réplique n'est plus affichée.
      delay.value = const Duration(seconds: 1);
      await tester.pump();
      expect(find.text('Salut'), findsNothing);
      track.value = null;
      await tester.pump();
    });
  });

  group('NativeEngine (traduction des événements)', () {
    test('état du plugin → PlayerSnapshot', () {
      final s = NativeEngine.snapshotFromEvent({
        'event': 'state',
        'status': 'ready',
        'playing': true,
        'buffering': false,
        'positionMs': 61500,
        'durationMs': 7200000,
        'bufferedMs': 90000.4,
        'rate': 1.25,
        'width': 3840.0,
        'height': 2160,
        'droppedFrames': 3,
      }, const PlayerSnapshot());
      expect(s.status, PlaybackStatus.ready);
      expect(s.playing, isTrue);
      expect(s.position, const Duration(milliseconds: 61500));
      expect(s.duration, const Duration(hours: 2));
      expect(s.buffered, const Duration(milliseconds: 90000));
      expect(s.rate, 1.25);
      expect(s.videoSize, const Size(3840, 2160));
      expect(s.droppedFrames, 3);
    });

    test('valeurs absentes : chargement, taille précédente conservée', () {
      final s = NativeEngine.snapshotFromEvent({
        'event': 'state',
        'width': 0,
      }, const PlayerSnapshot(videoSize: Size(1920, 1080), rate: 2));
      expect(s.status, PlaybackStatus.loading);
      expect(s.videoSize, const Size(1920, 1080));
      expect(s.rate, 2);
      expect(s.position, Duration.zero);
    });

    test('sous-titres demandés en WebVTT (ASS converti par le serveur)', () {
      Uri u(String s) => Uri.parse(s);
      expect(
        NativeEngine.asWebVtt(u('http://s/jf/Videos/m/src/Subtitles/3/0/Stream.ass')).toString(),
        'http://s/jf/Videos/m/src/Subtitles/3/0/Stream.vtt',
      );
      expect(
        NativeEngine.asWebVtt(u('http://s/Videos/m/src/Subtitles/5/0/Stream.srt?x=1')).toString(),
        'http://s/Videos/m/src/Subtitles/5/0/Stream.srt?x=1',
      );
      expect(NativeEngine.asWebVtt(u('http://s/Videos/m/src/Subtitles/5/0/Stream.vtt')).path, endsWith('Stream.vtt'));
      expect(NativeEngine.asWebVtt(u('http://s/autre/fichier.ass')).path, endsWith('fichier.ass'));
    });
  });

  group('PlaybackPreparer', () {
    PlaybackPlan withSource(PlaybackPlan p, SourceProfile source) => PlaybackPlan(
      itemId: p.itemId,
      mediaSourceId: p.mediaSourceId,
      playSessionId: p.playSessionId,
      method: p.method,
      streamUrl: p.streamUrl,
      audioTracks: p.audioTracks,
      subtitleTracks: p.subtitleTracks,
      audioIndex: p.audioIndex,
      subtitleIndex: p.subtitleIndex,
      source: source,
    );

    PlaybackPreparer preparer(FakePlaybackRepository repo, {DeviceCapabilities? device}) => PlaybackPreparer(
      repository: repo,
      device: device ?? iphone15Pro.caps,
      settings: const AppSettings(),
      maxBitrate: 120000000,
    );

    test('mpv en lecture directe : l’analyse sert de plan (une seule requête)', () async {
      final repo = FakePlaybackRepository(
        ({int? audioIndex, int? subtitleIndex, PlaybackRequestOptions? options}) =>
            withSource(plan(), files.firstWhere((f) => f.id == 'h264_mkv_dts').source),
      );
      final p = await preparer(repo).prepare('m');
      expect(p.decision.engine, EngineKind.mpv);
      expect(repo.prepareCalls, hasLength(1));
      // Analyse avec le profil natif (appareil compatible) ; mpv retenu : flux statique, sans 2e requête.
      expect(repo.prepareOptions.single!.deviceProfile['Name'], 'OptiFin (AVPlayer)');
      expect(p.plan.streamUrl.queryParameters['static'], 'true');
    });

    test('natif : second PlaybackInfo avec le profil natif et les options de la décision', () async {
      final repo = FakePlaybackRepository(
        ({int? audioIndex, int? subtitleIndex, PlaybackRequestOptions? options}) =>
            withSource(plan(), files.firstWhere((f) => f.id == 'hevc_hdr10_mkv').source),
      );
      final p = await preparer(repo).prepare('m');
      expect(p.decision.label, 'Natif · Remux');
      expect(repo.prepareCalls, hasLength(2));
      expect(repo.prepareCalls.last.$2, -1, reason: 'pas de sous-titre incrusté par défaut');
      final options = repo.prepareOptions.last!;
      expect(options.deviceProfile['Name'], 'OptiFin (AVPlayer)');
      expect((options.enableDirectPlay, options.enableDirectStream), (false, true));

      final fallback = await preparer(repo).planFor('m', p.selection, 1, probe: p.plan, audioIndex: p.audioIndex);
      expect(fallback.decision.engine, EngineKind.mpv);
      expect(fallback.hasFallback, isTrue);
      expect(repo.prepareCalls, hasLength(2), reason: 'repli mpv : plan d’analyse réutilisé');
    });

    PlaybackPlan withMethod(PlaybackPlan p, PlayMethod m) => PlaybackPlan(
      itemId: p.itemId,
      mediaSourceId: p.mediaSourceId,
      playSessionId: p.playSessionId,
      method: m,
      streamUrl: p.streamUrl,
      audioTracks: p.audioTracks,
      subtitleTracks: p.subtitleTracks,
      audioIndex: p.audioIndex,
      subtitleIndex: p.subtitleIndex,
      source: p.source,
    );

    test('natif en lecture directe : une seule requête (analyse = plan)', () async {
      final repo = FakePlaybackRepository(
        ({int? audioIndex, int? subtitleIndex, PlaybackRequestOptions? options}) =>
            withSource(plan(), files.firstWhere((f) => f.id == 'h264_mp4').source),
      );
      final p = await preparer(repo).prepare('m');
      expect(p.decision.label, 'Natif · Lecture directe');
      expect(repo.prepareCalls, hasLength(1));
    });

    test('remux natif : réutilisé si le serveur a remuxé la même piste audio', () async {
      final source = files.firstWhere((f) => f.id == 'hevc_hdr10_mkv').source;
      final repo = FakePlaybackRepository(
        ({int? audioIndex, int? subtitleIndex, PlaybackRequestOptions? options}) =>
            withMethod(withSource(plan(audioIndex: audioIndex ?? 1), source), PlayMethod.directStream),
      );
      final p = await preparer(repo).prepare('m');
      expect(p.decision.label, 'Natif · Remux');
      expect(repo.prepareCalls, hasLength(1));
      // Autre piste audio demandée : le remux du serveur ne la contient pas → nouvelle demande.
      await preparer(repo).prepare('m', explicitTracks: true, audioIndex: 2);
      expect(repo.prepareCalls, hasLength(3));
    });

    test('pistes explicites prioritaires sur les préférences', () async {
      final repo = FakePlaybackRepository(
        ({int? audioIndex, int? subtitleIndex, PlaybackRequestOptions? options}) =>
            withSource(plan(audioIndex: audioIndex ?? 1), files.firstWhere((f) => f.id == 'h264_mp4').source),
      );
      final p = await preparer(repo).prepare('m', explicitTracks: true, audioIndex: 2, subtitleIndex: 5);
      expect((p.audioIndex, p.subtitleIndex), (2, 5));
    });

    test('source non décrite : mpv puis transcodage', () {
      final s = preparer(
        FakePlaybackRepository(({int? audioIndex, int? subtitleIndex, PlaybackRequestOptions? options}) => plan()),
      ).select(plan());
      expect(s.chain.map(short), ['mpv/directPlay/none', 'mpv/transcode/none']);
    });
  });
}
