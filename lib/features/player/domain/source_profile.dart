/// Description technique d'une source média, telle que l'analyse l'[EngineSelector].
///
/// Construite à partir des `MediaStreams` de `PlaybackInfo` (voir
/// `sourceProfileFrom` côté data) ; pure, sans dépendance au client API.
library;

enum DynamicRange {
  sdr('SDR'),
  hdr10('HDR10'),
  hdr10Plus('HDR10+'),
  hlg('HLG'),
  dolbyVision('Dolby Vision');

  const DynamicRange(this.label);
  final String label;
}

class VideoInfo {
  const VideoInfo({
    required this.codec,
    this.profile,
    this.bitDepth,
    this.width,
    this.height,
    this.range = DynamicRange.sdr,
    this.dvProfile,
    this.dvBaseLayer,
  });

  /// Codec normalisé : h264, hevc, av1, vp9, vp8, mpeg2video, vc1, mpeg4…
  final String codec;
  final String? profile;
  final int? bitDepth;
  final int? width;
  final int? height;
  final DynamicRange range;

  /// Profil Dolby Vision (5, 7, 8…), null si pas de DV.
  final int? dvProfile;

  /// Couche de base exploitable sans décodeur DV (profils 7 / 8.x : HDR10, HLG
  /// ou SDR). null = aucune (profil 5 : couleurs fausses sans DV).
  final DynamicRange? dvBaseLayer;

  bool get isDolbyVision => range == DynamicRange.dolbyVision;
  bool get isHdr => range != DynamicRange.sdr;
  bool get is10Bit => (bitDepth ?? 8) > 8;
  bool get isUhd => (width ?? 0) > 1920 || (height ?? 0) > 1088;

  String get summary => [
    codec.toUpperCase(),
    if (width != null && height != null) '$width×$height',
    if (bitDepth != null) '$bitDepth bits',
    if (isDolbyVision)
      'DV p${dvProfile ?? '?'}${dvBaseLayer == null ? '' : ' (BL ${dvBaseLayer!.label})'}'
    else
      range.label,
  ].join(' · ');
}

class AudioInfo {
  const AudioInfo({required this.index, required this.codec, this.profile, this.channels, this.atmos = false});

  final int index;

  /// Codec normalisé : aac, mp3, ac3, eac3, truehd, dts, flac, alac, opus, vorbis, pcm…
  final String codec;

  /// Précision éventuelle (« DTS-HD MA », « LC »…).
  final String? profile;
  final int? channels;
  final bool atmos;
}

class SubtitleInfo {
  const SubtitleInfo({required this.index, required this.codec, this.isText = true, this.isExternal = false});

  final int index;
  final String codec;
  final bool isText;
  final bool isExternal;

  bool get isAss => codec == 'ass' || codec == 'ssa';
  bool get isBitmap => !isText;
}

class SourceProfile {
  const SourceProfile({
    required this.container,
    this.bitrate,
    this.video,
    this.audio = const [],
    this.subtitles = const [],
  });

  /// Conteneur(s) tels que Jellyfin les décrit (« mkv », « mov,mp4,m4a… »).
  final String container;
  final int? bitrate;
  final VideoInfo? video;
  final List<AudioInfo> audio;
  final List<SubtitleInfo> subtitles;

  Set<String> get containers => {
    for (final c in container.toLowerCase().split(','))
      if (c.trim().isNotEmpty) c.trim(),
  };

  AudioInfo? audioAt(int? index) =>
      index == null ? audio.firstOrNull : (audio.where((a) => a.index == index).firstOrNull ?? audio.firstOrNull);

  SubtitleInfo? subtitleAt(int? index) =>
      index == null || index < 0 ? null : subtitles.where((s) => s.index == index).firstOrNull;
}

/// Normalise les noms de codecs de Jellyfin/ffmpeg vers ceux de l'EngineSelector.
String normalizeCodec(String? codec) {
  final c = (codec ?? '').toLowerCase().trim();
  return switch (c) {
    'avc' || 'avc1' || 'h.264' => 'h264',
    'h265' || 'hvc1' || 'hev1' || 'h.265' || 'dvhe' || 'dvh1' => 'hevc',
    'av01' => 'av1',
    'mlp' || 'truehd' => 'truehd',
    'dca' || 'dts' || 'dts-hd' || 'dtshd' => 'dts',
    'ec3' || 'eac3' || 'e-ac-3' => 'eac3',
    'ac-3' || 'ac3' => 'ac3',
    'subrip' => 'srt',
    'webvtt' => 'vtt',
    'pgs' || 'hdmv_pgs_subtitle' => 'pgssub',
    'dvd_subtitle' => 'dvdsub',
    'dvb_subtitle' => 'dvbsub',
    _ when c.startsWith('pcm') => 'pcm',
    _ => c,
  };
}
