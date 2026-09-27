/// Matrice de test du choix de moteur : fichiers types × appareils types.
///
/// Source unique de `docs/TEST_MATRIX.md` (régénérée par le test
/// `engine_selector_test.dart` avec `UPDATE_MATRIX=1`).
library;

import 'package:optifin/features/player/domain/device_capabilities.dart';
import 'package:optifin/features/player/domain/engine_selector.dart';
import 'package:optifin/features/player/domain/source_profile.dart';

class MatrixFile {
  const MatrixFile(this.id, this.label, this.source, {this.subtitleIndex});

  final String id;
  final String label;
  final SourceProfile source;
  final int? subtitleIndex;
}

class MatrixDevice {
  const MatrixDevice(this.id, this.label, this.caps);

  final String id;
  final String label;
  final DeviceCapabilities caps;
}

// ------------------------------------------------------------------ Appareils

const iphone15Pro = MatrixDevice(
  'iphone15pro',
  'iPhone 15 Pro (iOS 18)',
  DeviceCapabilities(
    platform: DevicePlatform.ios,
    videoCodecs: {'h264', 'hevc', 'av1'},
    hevcMain10: true,
    ranges: {DynamicRange.sdr, DynamicRange.hdr10, DynamicRange.hlg, DynamicRange.dolbyVision},
    dolbyVisionProfiles: {5, 8},
    audioCodecs: {'aac', 'mp3', 'ac3', 'eac3', 'alac', 'flac'},
    containers: {'mp4', 'm4v', 'mov'},
    maxWidth: 3840,
  ),
);

const iphone11 = MatrixDevice(
  'iphone11',
  'iPhone 11 (sans AV1)',
  DeviceCapabilities(
    platform: DevicePlatform.ios,
    videoCodecs: {'h264', 'hevc'},
    hevcMain10: true,
    ranges: {DynamicRange.sdr, DynamicRange.hdr10, DynamicRange.hlg, DynamicRange.dolbyVision},
    dolbyVisionProfiles: {5, 8},
    audioCodecs: {'aac', 'mp3', 'ac3', 'eac3', 'alac', 'flac'},
    containers: {'mp4', 'm4v', 'mov'},
    maxWidth: 3840,
  ),
);

const pixel8 = MatrixDevice(
  'pixel8',
  'Pixel 8 (Android 15, HDR sans DV)',
  DeviceCapabilities(
    platform: DevicePlatform.android,
    videoCodecs: {'h264', 'hevc', 'vp9', 'av1'},
    hevcMain10: true,
    ranges: {DynamicRange.sdr, DynamicRange.hdr10, DynamicRange.hdr10Plus, DynamicRange.hlg},
    audioCodecs: {'aac', 'mp3', 'ac3', 'eac3', 'flac', 'opus', 'vorbis'},
    containers: {'mp4', 'm4v', 'mov', 'mkv', 'webm', 'ts', 'mpegts'},
    maxWidth: 3840,
  ),
);

const androidBasic = MatrixDevice(
  'android_basic',
  'Android entrée de gamme (1080p, SDR)',
  DeviceCapabilities(
    platform: DevicePlatform.android,
    videoCodecs: {'h264', 'hevc'},
    audioCodecs: {'aac', 'mp3', 'flac', 'opus', 'vorbis'},
    containers: {'mp4', 'm4v', 'mov', 'mkv', 'webm', 'ts', 'mpegts'},
  ),
);

const androidDv = MatrixDevice(
  'android_dv',
  'Box Android TV Dolby Vision',
  DeviceCapabilities(
    platform: DevicePlatform.android,
    videoCodecs: {'h264', 'hevc', 'vp9', 'av1'},
    hevcMain10: true,
    ranges: {DynamicRange.sdr, DynamicRange.hdr10, DynamicRange.hlg, DynamicRange.dolbyVision},
    dolbyVisionProfiles: {5, 7, 8},
    audioCodecs: {'aac', 'mp3', 'ac3', 'eac3', 'flac', 'opus', 'vorbis', 'dts', 'truehd'},
    containers: {'mp4', 'm4v', 'mov', 'mkv', 'webm', 'ts', 'mpegts'},
    maxWidth: 3840,
  ),
);

const devices = [iphone15Pro, iphone11, pixel8, androidBasic, androidDv];

// ------------------------------------------------------------------ Fichiers

const _uhd = (3840, 2160);
const _fhd = (1920, 1080);

VideoInfo _v(
  String codec,
  (int, int) size, {
  int bits = 8,
  DynamicRange range = DynamicRange.sdr,
  int? dv,
  DynamicRange? bl,
}) => VideoInfo(
  codec: codec,
  width: size.$1,
  height: size.$2,
  bitDepth: bits,
  range: range,
  dvProfile: dv,
  dvBaseLayer: bl,
);

const _eac3 = AudioInfo(index: 1, codec: 'eac3', channels: 6);
const _eac3Atmos = AudioInfo(index: 1, codec: 'eac3', channels: 6, atmos: true);
const _aac = AudioInfo(index: 1, codec: 'aac', channels: 2);
const _ac3 = AudioInfo(index: 1, codec: 'ac3', channels: 6);
const _truehdAtmos = AudioInfo(index: 1, codec: 'truehd', profile: 'TrueHD Atmos', channels: 8, atmos: true);
const _dtsHd = AudioInfo(index: 1, codec: 'dts', profile: 'DTS-HD MA', channels: 8);
const _opus = AudioInfo(index: 1, codec: 'opus', channels: 6);
const _mp3 = AudioInfo(index: 1, codec: 'mp3', channels: 2);

final files = [
  MatrixFile(
    'h264_mp4',
    'MP4 H.264 1080p, AAC, SRT externe',
    SourceProfile(
      container: 'mov,mp4,m4a,3gp,3g2,mj2',
      bitrate: 8000000,
      video: _v('h264', _fhd),
      audio: const [_aac],
      subtitles: const [SubtitleInfo(index: 2, codec: 'srt', isExternal: true)],
    ),
    subtitleIndex: 2,
  ),
  MatrixFile(
    'hevc_hdr10_mkv',
    'MKV HEVC 10 bits HDR10 4K, E-AC3 5.1',
    SourceProfile(
      container: 'mkv',
      bitrate: 45000000,
      video: _v('hevc', _uhd, bits: 10, range: DynamicRange.hdr10),
      audio: const [_eac3],
    ),
  ),
  MatrixFile(
    'dv8_mkv_truehd_pgs',
    'MKV DV profil 8.1 4K, TrueHD Atmos, PGS',
    SourceProfile(
      container: 'mkv',
      bitrate: 60000000,
      video: _v('hevc', _uhd, bits: 10, range: DynamicRange.dolbyVision, dv: 8, bl: DynamicRange.hdr10),
      audio: const [_truehdAtmos],
      subtitles: const [SubtitleInfo(index: 2, codec: 'pgssub', isText: false)],
    ),
    subtitleIndex: 2,
  ),
  MatrixFile(
    'dv8_mkv_truehd',
    'MKV DV profil 8.1 4K, TrueHD Atmos, sans sous-titres',
    SourceProfile(
      container: 'mkv',
      bitrate: 60000000,
      video: _v('hevc', _uhd, bits: 10, range: DynamicRange.dolbyVision, dv: 8, bl: DynamicRange.hdr10),
      audio: const [_truehdAtmos],
    ),
  ),
  MatrixFile(
    'dv5_mp4',
    'MP4 DV profil 5 4K, E-AC3 Atmos',
    SourceProfile(
      container: 'mov,mp4,m4a,3gp,3g2,mj2',
      bitrate: 25000000,
      video: _v('hevc', _uhd, bits: 10, range: DynamicRange.dolbyVision, dv: 5),
      audio: const [_eac3Atmos],
    ),
  ),
  MatrixFile(
    'dv7_mkv',
    'MKV DV profil 7 (BL+EL) 4K, TrueHD',
    SourceProfile(
      container: 'mkv',
      bitrate: 70000000,
      video: _v('hevc', _uhd, bits: 10, range: DynamicRange.dolbyVision, dv: 7, bl: DynamicRange.hdr10),
      audio: const [_truehdAtmos],
    ),
  ),
  MatrixFile(
    'av1_hdr10_mkv',
    'MKV AV1 10 bits HDR10 4K, Opus 5.1',
    SourceProfile(
      container: 'mkv',
      bitrate: 20000000,
      video: _v('av1', _uhd, bits: 10, range: DynamicRange.hdr10),
      audio: const [_opus],
    ),
  ),
  MatrixFile(
    'hlg_mkv',
    'MKV HEVC HLG 4K, AAC',
    SourceProfile(
      container: 'mkv',
      bitrate: 30000000,
      video: _v('hevc', _uhd, bits: 10, range: DynamicRange.hlg),
      audio: const [_aac],
    ),
  ),
  MatrixFile(
    'h264_mkv_dts',
    'MKV H.264 1080p, DTS-HD MA 7.1',
    SourceProfile(container: 'mkv', bitrate: 25000000, video: _v('h264', _fhd), audio: const [_dtsHd]),
  ),
  MatrixFile(
    'h264_mkv_ass',
    'MKV H.264 1080p, AAC, ASS',
    SourceProfile(
      container: 'mkv',
      bitrate: 6000000,
      video: _v('h264', _fhd),
      audio: const [_aac],
      subtitles: const [SubtitleInfo(index: 2, codec: 'ass')],
    ),
    subtitleIndex: 2,
  ),
  MatrixFile(
    'hevc_mkv_pgs',
    'MKV HEVC 1080p SDR, AC3, PGS',
    SourceProfile(
      container: 'mkv',
      bitrate: 12000000,
      video: _v('hevc', _fhd),
      audio: const [_ac3],
      subtitles: const [SubtitleInfo(index: 2, codec: 'pgssub', isText: false)],
    ),
    subtitleIndex: 2,
  ),
  MatrixFile(
    'h264_mp4_movtext',
    'MP4 H.264 1080p, AC3, sous-titres mov_text',
    SourceProfile(
      container: 'mov,mp4,m4a,3gp,3g2,mj2',
      bitrate: 9000000,
      video: _v('h264', _fhd),
      audio: const [_ac3],
      subtitles: const [SubtitleInfo(index: 2, codec: 'mov_text')],
    ),
    subtitleIndex: 2,
  ),
  MatrixFile(
    'vp9_webm',
    'WebM VP9 1080p, Opus',
    SourceProfile(container: 'webm', bitrate: 4000000, video: _v('vp9', _fhd), audio: const [_opus]),
  ),
  MatrixFile(
    'xvid_avi',
    'AVI MPEG-4 ASP (Xvid) 480p, MP3',
    SourceProfile(container: 'avi', bitrate: 1500000, video: _v('mpeg4', (720, 480)), audio: const [_mp3]),
  ),
  MatrixFile(
    'vc1_mkv',
    'MKV VC-1 1080p, AC3',
    SourceProfile(container: 'mkv', bitrate: 20000000, video: _v('vc1', _fhd), audio: const [_ac3]),
  ),
  MatrixFile(
    'av1_uhd_sdr',
    'MKV AV1 4K SDR, Opus',
    SourceProfile(container: 'mkv', bitrate: 15000000, video: _v('av1', _uhd), audio: const [_opus]),
  ),
];

/// Décision attendue, en abrégé : `moteur/livraison/sous-titres`.
String short(EngineDecision d) => '${d.engine.name}/${d.delivery.name}/${d.subtitles.name}';
