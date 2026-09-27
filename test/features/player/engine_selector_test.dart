import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/features/player/data/device_profiles.dart';
import 'package:optifin/features/player/domain/device_capabilities.dart';
import 'package:optifin/features/player/domain/engine_selector.dart';
import 'package:optifin/features/player/domain/source_profile.dart';

import 'engine_matrix.dart';

/// Décisions attendues pour chaque fichier de la matrice, par appareil
/// (ordre de [devices] : iPhone 15 Pro, iPhone 11, Pixel 8, Android basique, box DV).
const expected = <String, List<String>>{
  'h264_mp4': [
    'native/directPlay/overlay',
    'native/directPlay/overlay',
    'native/directPlay/overlay',
    'native/directPlay/overlay',
    'native/directPlay/overlay',
  ],
  'hevc_hdr10_mkv': [
    'native/remux/none',
    'native/remux/none',
    'native/directPlay/none',
    'native/transcode/none',
    'native/directPlay/none',
  ],
  'dv8_mkv_truehd_pgs': [
    'mpv/directPlay/engine',
    'mpv/directPlay/engine',
    'mpv/directPlay/engine',
    'native/transcode/burnIn',
    'mpv/directPlay/engine',
  ],
  'dv8_mkv_truehd': [
    'native/remux/none',
    'native/remux/none',
    'native/remux/none',
    'native/transcode/none',
    'native/directPlay/none',
  ],
  'dv5_mp4': [
    'native/directPlay/none',
    'native/directPlay/none',
    'native/transcode/none',
    'native/transcode/none',
    'native/directPlay/none',
  ],
  'dv7_mkv': [
    'native/remux/none',
    'native/remux/none',
    'native/remux/none',
    'native/transcode/none',
    'native/directPlay/none',
  ],
  'av1_hdr10_mkv': [
    'native/remux/none',
    'native/transcode/none',
    'native/directPlay/none',
    'native/transcode/none',
    'native/directPlay/none',
  ],
  'hlg_mkv': [
    'native/remux/none',
    'native/remux/none',
    'native/directPlay/none',
    'native/transcode/none',
    'native/directPlay/none',
  ],
  'h264_mkv_dts': [
    'mpv/directPlay/none',
    'mpv/directPlay/none',
    'mpv/directPlay/none',
    'mpv/directPlay/none',
    'native/directPlay/none',
  ],
  'h264_mkv_ass': [
    'mpv/directPlay/engine',
    'mpv/directPlay/engine',
    'mpv/directPlay/engine',
    'mpv/directPlay/engine',
    'mpv/directPlay/engine',
  ],
  'hevc_mkv_pgs': [
    'mpv/directPlay/engine',
    'mpv/directPlay/engine',
    'mpv/directPlay/engine',
    'mpv/directPlay/engine',
    'mpv/directPlay/engine',
  ],
  'h264_mp4_movtext': [
    'native/directPlay/overlay',
    'native/directPlay/overlay',
    'native/directPlay/overlay',
    'mpv/directPlay/engine',
    'native/directPlay/overlay',
  ],
  'vp9_webm': [
    'mpv/directPlay/none',
    'mpv/directPlay/none',
    'native/directPlay/none',
    'mpv/directPlay/none',
    'native/directPlay/none',
  ],
  'xvid_avi': [
    'mpv/directPlay/none',
    'mpv/directPlay/none',
    'mpv/directPlay/none',
    'mpv/directPlay/none',
    'mpv/directPlay/none',
  ],
  'vc1_mkv': [
    'mpv/directPlay/none',
    'mpv/directPlay/none',
    'mpv/directPlay/none',
    'mpv/directPlay/none',
    'mpv/directPlay/none',
  ],
  'av1_uhd_sdr': [
    'mpv/directPlay/none',
    'native/transcode/none',
    'native/directPlay/none',
    'native/transcode/none',
    'native/directPlay/none',
  ],
};

EngineSelection sel(
  MatrixFile f,
  MatrixDevice d, {
  EnginePreference preference = EnginePreference.auto,
  ImageSubtitlePolicy image = ImageSubtitlePolicy.auto,
  int maxBitrate = 120000000,
  int? audioIndex,
  bool force = false,
}) => EngineSelector.select(
  SelectionRequest(
    source: f.source,
    device: d.caps,
    audioIndex: audioIndex,
    subtitleIndex: f.subtitleIndex,
    preference: preference,
    imageSubtitles: image,
    maxBitrate: maxBitrate,
    forceTranscode: force,
  ),
);

MatrixFile file(String id) => files.firstWhere((f) => f.id == id);

void main() {
  group('Matrice fichiers × appareils', () {
    test('couvre tous les fichiers', () {
      expect(expected.keys.toSet(), files.map((f) => f.id).toSet());
    });

    for (final f in files) {
      for (final (i, d) in devices.indexed) {
        test('${f.id} sur ${d.id}', () {
          expect(short(sel(f, d).primary), expected[f.id]![i]);
        });
      }
    }

    test('docs/TEST_MATRIX.md est à jour (UPDATE_MATRIX=1 pour régénérer)', () {
      final doc = File('docs/TEST_MATRIX.md');
      const begin = '<!-- matrice:début -->';
      const end = '<!-- matrice:fin -->';
      final generated = _markdownMatrix();
      if (Platform.environment['UPDATE_MATRIX'] == '1') {
        final text = doc.readAsStringSync();
        final start = text.indexOf(begin) + begin.length;
        doc.writeAsStringSync('${text.substring(0, start)}\n$generated\n${text.substring(text.indexOf(end))}');
      }
      final text = doc.readAsStringSync();
      final current = text.substring(text.indexOf(begin) + begin.length, text.indexOf(end)).trim();
      expect(current, generated.trim());
    });
  });

  group('Invariants (tous fichiers, appareils et préférences)', () {
    final unavailable = MatrixDevice('none', 'sans natif', DeviceCapabilities.fallback(DevicePlatform.other));
    final allDevices = [...devices, unavailable];

    for (final pref in EnginePreference.values) {
      for (final image in ImageSubtitlePolicy.values) {
        test('préférence ${pref.name}, sous-titres image ${image.name}', () {
          for (final f in files) {
            for (final d in allDevices) {
              final s = sel(f, d, preference: pref, image: image);
              final where = '${f.id} / ${d.id}';
              for (final decision in s.chain) {
                // Cohérence moteur / sous-titres.
                if (decision.subtitles == SubtitleRoute.overlay) expect(decision.isNative, isTrue, reason: where);
                if (decision.subtitles == SubtitleRoute.engine) {
                  expect(decision.engine, EngineKind.mpv, reason: where);
                }
                if (decision.subtitles == SubtitleRoute.burnIn) {
                  expect(decision.delivery, Delivery.transcode, reason: where);
                  expect(decision.reencodeVideo, isTrue, reason: where);
                }
                if (f.subtitleIndex == null) expect(decision.subtitles, SubtitleRoute.none, reason: where);
                // mpv ne remuxe jamais : il lit le fichier tel quel.
                if (decision.engine == EngineKind.mpv) expect(decision.delivery, isNot(Delivery.remux), reason: where);
                if (!d.caps.nativeAvailable) expect(decision.isNative, isFalse, reason: where);
                expect(decision.reason, isNotEmpty, reason: where);
              }
              // Replis : jamais la décision principale, jamais deux fois la même route.
              for (final (i, fb) in s.fallbacks.indexed) {
                expect(fb.sameRoute(s.primary), isFalse, reason: where);
                expect(s.fallbacks.skip(i + 1).any(fb.sameRoute), isFalse, reason: where);
              }
              expect(s.trace.last, startsWith('→ '), reason: where);
            }
          }
        });
      }
    }

    test('le dernier recours est toujours un transcodage', () {
      for (final f in files) {
        for (final d in devices) {
          expect(sel(f, d).chain.last.delivery, Delivery.transcode, reason: '${f.id} / ${d.id}');
        }
      }
    });

    test('Dolby Vision sans sous-titres image : toujours le lecteur natif', () {
      for (final f in files.where((f) => f.source.video?.isDolbyVision ?? false)) {
        if (f.source.subtitleAt(f.subtitleIndex)?.isBitmap ?? false) continue;
        for (final d in devices) {
          expect(sel(f, d).primary.engine, EngineKind.native, reason: '${f.id} / ${d.id}');
        }
      }
    });
  });

  group('Règles', () {
    test('débit source trop élevé → transcodage (natif ; mpv si préféré)', () {
      final f = file('hevc_hdr10_mkv');
      final s = sel(f, iphone15Pro, maxBitrate: 10000000);
      expect(short(s.primary), 'native/transcode/none');
      expect(s.primary.reason, contains('45 Mb/s'));
      expect(s.primary.reason, contains('10 Mb/s'));
      expect(short(s.fallbacks.single), 'mpv/transcode/none');
      expect(
        short(sel(f, iphone15Pro, maxBitrate: 10000000, preference: EnginePreference.mpv).primary),
        'mpv/transcode/none',
      );
    });

    test('débit égal à la limite : pas de transcodage', () {
      final f = file('hevc_hdr10_mkv');
      expect(sel(f, pixel8, maxBitrate: 45000000).primary.delivery, Delivery.directPlay);
    });

    test('transcodage forcé', () {
      final s = sel(file('h264_mp4'), iphone15Pro, force: true);
      expect(short(s.primary), 'native/transcode/overlay');
      expect(s.primary.reason, 'Transcodage demandé');
    });

    test('préférence mpv : lecture directe mpv, sauf si mpv ne sait pas (DV profil 5)', () {
      expect(
        short(sel(file('dv8_mkv_truehd'), iphone15Pro, preference: EnginePreference.mpv).primary),
        'mpv/directPlay/none',
      );
      final dv5 = sel(file('dv5_mp4'), iphone15Pro, preference: EnginePreference.mpv);
      expect(short(dv5.primary), 'mpv/transcode/none');
      expect(dv5.primary.reason, contains('profil 5'));
      expect(dv5.primary.reencodeVideo, isFalse);
    });

    test('préférence natif : remux plutôt que mpv, sous-titres ASS en surimpression', () {
      final s = sel(file('h264_mkv_ass'), iphone15Pro, preference: EnginePreference.native);
      expect(short(s.primary), 'native/remux/overlay');
      expect(s.primary.reason, contains('conteneur MKV'));
      expect(short(s.fallbacks.first), 'mpv/directPlay/engine');
    });

    test('préférence natif impossible (vidéo illisible) → transcodage natif', () {
      final s = sel(file('vc1_mkv'), iphone15Pro, preference: EnginePreference.native);
      expect(short(s.primary), 'native/transcode/none');
      expect(s.primary.reason, contains('VC1'));
    });

    test('préférence natif sans lecteur natif → automatique (mpv)', () {
      final none = DeviceCapabilities.fallback(DevicePlatform.other);
      final s = EngineSelector.select(
        SelectionRequest(source: file('h264_mp4').source, device: none, preference: EnginePreference.native),
      );
      expect(s.primary.engine, EngineKind.mpv);
      expect(s.chain.every((d) => d.engine == EngineKind.mpv), isTrue);
    });

    test('sous-titres image sur DV, politique « incruster » → natif + incrustation', () {
      final s = sel(file('dv8_mkv_truehd_pgs'), iphone15Pro, image: ImageSubtitlePolicy.burnIn);
      expect(short(s.primary), 'native/transcode/burnIn');
      expect(s.primary.reencodeVideo, isTrue);
    });

    test('sous-titres image sur DV profil 5 : mpv impossible → incrustation', () {
      final base = file('dv5_mp4');
      final withPgs = MatrixFile(
        'dv5_pgs',
        '',
        SourceProfile(
          container: base.source.container,
          bitrate: base.source.bitrate,
          video: base.source.video,
          audio: base.source.audio,
          subtitles: const [SubtitleInfo(index: 2, codec: 'pgssub', isText: false)],
        ),
        subtitleIndex: 2,
      );
      expect(short(sel(withPgs, iphone15Pro).primary), 'native/transcode/burnIn');
    });

    test('ASS sur HDR10 → mpv (styles) ; ASS sur Dolby Vision → natif, ASS simplifiés', () {
      SourceProfile withAss(SourceProfile s) => SourceProfile(
        container: s.container,
        bitrate: s.bitrate,
        video: s.video,
        audio: s.audio,
        subtitles: const [SubtitleInfo(index: 9, codec: 'ass')],
      );
      final hdr = EngineSelector.select(
        SelectionRequest(source: withAss(file('hevc_hdr10_mkv').source), device: pixel8.caps, subtitleIndex: 9),
      );
      expect(short(hdr.primary), 'mpv/directPlay/engine');
      final dv = EngineSelector.select(
        SelectionRequest(source: withAss(file('dv8_mkv_truehd').source), device: androidDv.caps, subtitleIndex: 9),
      );
      expect(short(dv.primary), 'native/directPlay/overlay');
      expect(dv.primary.reason, contains('ASS simplifiés'));
    });

    test('le choix de la piste audio change la décision (E-AC3 → DTS)', () {
      const source = SourceProfile(
        container: 'mp4',
        video: VideoInfo(codec: 'h264', width: 1920, height: 1080),
        audio: [
          AudioInfo(index: 1, codec: 'eac3'),
          AudioInfo(index: 2, codec: 'dts', profile: 'DTS-HD MA'),
        ],
      );
      SelectionRequest req(int audio) => SelectionRequest(source: source, device: iphone15Pro.caps, audioIndex: audio);
      expect(EngineSelector.select(req(1)).primary.engine, EngineKind.native);
      final dts = EngineSelector.select(req(2));
      expect(dts.primary.engine, EngineKind.mpv);
      expect(dts.primary.reason, contains('DTS-HD MA'));
      // Index inconnu : première piste.
      expect(EngineSelector.select(req(42)).primary.engine, EngineKind.native);
    });

    test('sous-titre -1 ou inconnu = aucun', () {
      for (final index in [-1, 99]) {
        final s = EngineSelector.select(
          SelectionRequest(source: file('hevc_mkv_pgs').source, device: pixel8.caps, subtitleIndex: index),
        );
        expect(s.primary.subtitles, SubtitleRoute.none);
      }
    });

    test('audio seul (pas de vidéo) : natif si conteneur et codec passent', () {
      const flac = SourceProfile(
        container: 'flac',
        audio: [AudioInfo(index: 0, codec: 'flac')],
      );
      final caps = DeviceCapabilities.fromJson({
        'platform': 'android',
        'containers': ['flac', 'mp4'],
        'audioCodecs': ['flac', 'aac'],
      });
      expect(
        short(EngineSelector.select(SelectionRequest(source: flac, device: caps)).primary),
        'native/directPlay/none',
      );
    });

    test('HDR10+ lu comme HDR10 ; HDR sur écran SDR Android → mpv (conversion)', () {
      const hdr10Plus = SourceProfile(
        container: 'mkv',
        video: VideoInfo(codec: 'hevc', width: 3840, height: 2160, bitDepth: 10, range: DynamicRange.hdr10Plus),
        audio: [AudioInfo(index: 1, codec: 'eac3')],
      );
      expect(
        EngineSelector.select(SelectionRequest(source: hdr10Plus, device: androidDv.caps)).primary.engine,
        EngineKind.native,
      );
      const sdrScreen = DeviceCapabilities(
        platform: DevicePlatform.android,
        videoCodecs: {'h264', 'hevc'},
        hevcMain10: true,
        audioCodecs: {'aac', 'eac3'},
        containers: {'mkv', 'mp4'},
        maxWidth: 3840,
      );
      final s = EngineSelector.select(const SelectionRequest(source: hdr10Plus, device: sdrScreen));
      expect(short(s.primary), 'mpv/directPlay/none');
      expect(s.primary.reason, contains('non affichable'));
    });

    test('conteneur vide ou inconnu : pas bloquant', () {
      const s = SourceProfile(
        container: '',
        video: VideoInfo(codec: 'h264', width: 1280, height: 720),
      );
      expect(
        EngineSelector.select(SelectionRequest(source: s, device: iphone11.caps)).primary.delivery,
        Delivery.directPlay,
      );
    });

    test('trace lisible pour l’overlay de debug', () {
      final s = sel(file('dv8_mkv_truehd'), iphone15Pro);
      expect(s.trace.first, startsWith('Source : mkv, 60 Mb/s'));
      expect(s.trace, contains(contains('DV p8 (BL HDR10)')));
      expect(s.trace, contains(contains('audio : non (audio TrueHD Atmos)')));
      expect(s.trace.last, contains('Natif · Remux'));
    });
  });

  group('Options de requête', () {
    test('par livraison', () {
      const caps = DeviceCapabilities(platform: DevicePlatform.ios);
      PlaybackRequestOptions o(EngineDecision d) => PlaybackRequestOptions.forDecision(d, caps, 8000000);

      final dp = o(const EngineDecision(EngineKind.native, Delivery.directPlay, reason: ''));
      expect((dp.enableDirectPlay, dp.enableDirectStream, dp.allowVideoStreamCopy), (true, true, true));
      expect(dp.deviceProfile['Name'], 'OptiFin (AVPlayer)');
      expect(dp.deviceProfile['MaxStreamingBitrate'], 8000000);

      final remux = o(const EngineDecision(EngineKind.native, Delivery.remux, reason: ''));
      expect((remux.enableDirectPlay, remux.enableDirectStream, remux.allowVideoStreamCopy), (false, true, true));

      final burn = o(
        const EngineDecision(
          EngineKind.native,
          Delivery.transcode,
          subtitles: SubtitleRoute.burnIn,
          reencodeVideo: true,
          reason: '',
        ),
      );
      expect((burn.enableDirectPlay, burn.enableDirectStream, burn.allowVideoStreamCopy), (false, false, false));

      final mpv = o(const EngineDecision(EngineKind.mpv, Delivery.transcode, reason: ''));
      expect(mpv.deviceProfile['Name'], 'OptiFin (mpv)');
      expect(mpv.allowVideoStreamCopy, isTrue);
    });
  });
}

String _markdownMatrix() {
  final b = StringBuffer()
    ..writeln('| Fichier | ${devices.map((d) => d.label).join(' | ')} |')
    ..writeln('|---|${devices.map((_) => '---').join('|')}|');
  String cell(EngineDecision d) {
    final sub = switch (d.subtitles) {
      SubtitleRoute.none => '',
      SubtitleRoute.engine => ', ST moteur',
      SubtitleRoute.overlay => ', ST OptiFin',
      SubtitleRoute.burnIn => ', ST incrustés',
    };
    return '**${d.engine.label}** · ${d.delivery.label}$sub';
  }

  for (final f in files) {
    b.writeln('| ${f.label} | ${devices.map((d) => cell(sel(f, d).primary)).join(' | ')} |');
  }
  b
    ..writeln()
    ..writeln('### Raisons et replis')
    ..writeln();
  for (final f in files) {
    b.writeln('**${f.label}**');
    b.writeln();
    for (final d in devices) {
      final s = sel(f, d);
      final fallbacks = s.fallbacks.isEmpty ? '' : ' — replis : ${s.fallbacks.map((x) => x.label).join(' → ')}';
      b.writeln('- ${d.label} : ${s.primary.reason}$fallbacks');
    }
    b.writeln();
  }
  return b.toString().trimRight();
}
