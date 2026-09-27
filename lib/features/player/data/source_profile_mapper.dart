import 'package:jellyfin_api/jellyfin_api.dart';

import '../domain/source_profile.dart';

/// Traduit une `MediaSourceInfo` de Jellyfin en [SourceProfile] pour l'EngineSelector.
SourceProfile sourceProfileFrom(MediaSourceInfo source) {
  final streams = [...?source.mediaStreams]..sort((a, b) => (a.index ?? 0).compareTo(b.index ?? 0));
  final video = streams.where((s) => s.type == MediaStreamType.video).firstOrNull;
  return SourceProfile(
    container: source.container ?? '',
    bitrate: source.bitrate,
    video: video == null ? null : _video(video),
    audio: [
      for (final s in streams)
        if (s.type == MediaStreamType.audio && s.index != null)
          AudioInfo(
            index: s.index!,
            codec: normalizeCodec(s.codec),
            profile: _audioProfile(s),
            channels: s.channels,
            atmos:
                s.audioSpatialFormat == MediaStreamAudioSpatialFormat.dolbyAtmos ||
                (s.profile?.toLowerCase().contains('atmos') ?? false),
          ),
    ],
    subtitles: [
      for (final s in streams)
        if (s.type == MediaStreamType.subtitle && s.index != null)
          SubtitleInfo(
            index: s.index!,
            codec: normalizeCodec(s.codec),
            isText: s.isTextSubtitleStream ?? _isTextCodec(normalizeCodec(s.codec)),
            isExternal: s.isExternal ?? false,
          ),
    ],
  );
}

VideoInfo _video(MediaStream s) {
  final (range, dvBase) = _range(s);
  return VideoInfo(
    codec: normalizeCodec(s.codec),
    profile: s.profile,
    bitDepth: s.bitDepth ?? (s.pixelFormat?.contains('10') == true ? 10 : null),
    width: s.width,
    height: s.height,
    range: range,
    dvProfile: range == DynamicRange.dolbyVision ? s.dvProfile : null,
    dvBaseLayer: dvBase,
  );
}

/// Gamme dynamique et, pour le Dolby Vision, la couche de base exploitable sans DV.
(DynamicRange, DynamicRange?) _range(MediaStream s) {
  const dv = DynamicRange.dolbyVision;
  // Compatibilité signalée dans l'en-tête DV : 1/6 = HDR10, 2 = SDR, 4 = HLG, 0 = aucune (profil 5).
  final fromCompat = switch (s.dvBlSignalCompatibilityId) {
    1 || 6 => DynamicRange.hdr10,
    2 => DynamicRange.sdr,
    4 => DynamicRange.hlg,
    _ => null,
  };
  return switch (s.videoRangeType) {
    MediaStreamVideoRangeType.sdr => (DynamicRange.sdr, null),
    MediaStreamVideoRangeType.hdr10 => (DynamicRange.hdr10, null),
    MediaStreamVideoRangeType.hdr10Plus => (DynamicRange.hdr10Plus, null),
    MediaStreamVideoRangeType.hlg => (DynamicRange.hlg, null),
    MediaStreamVideoRangeType.dovi => (dv, s.dvProfile == 5 ? null : fromCompat),
    MediaStreamVideoRangeType.doviWithHdr10 ||
    MediaStreamVideoRangeType.doviWithHdr10Plus ||
    MediaStreamVideoRangeType.doviWithEl ||
    MediaStreamVideoRangeType.doviWithElhdr10Plus => (dv, fromCompat ?? DynamicRange.hdr10),
    MediaStreamVideoRangeType.doviWithHlg => (dv, DynamicRange.hlg),
    MediaStreamVideoRangeType.doviWithSdr => (dv, DynamicRange.sdr),
    // Métadonnées DV corrompues : Jellyfin les ignore, reste le HDR10 sous-jacent.
    MediaStreamVideoRangeType.doviInvalid => (DynamicRange.hdr10, null),
    _ => (_rangeFromTransfer(s), null),
  };
}

/// Serveurs anciens (sans VideoRangeType) : on se fie à la fonction de transfert.
DynamicRange _rangeFromTransfer(MediaStream s) => switch (s.colorTransfer?.toLowerCase()) {
  'smpte2084' => DynamicRange.hdr10,
  'arib-std-b67' => DynamicRange.hlg,
  _ => s.videoRange == MediaStreamVideoRange.hdr ? DynamicRange.hdr10 : DynamicRange.sdr,
};

String? _audioProfile(MediaStream s) {
  final codec = normalizeCodec(s.codec);
  final profile = s.profile;
  if (codec == 'dts' && profile != null && profile.isNotEmpty) return profile; // « DTS-HD MA », « DTS:X »
  if (codec == 'truehd') return profile?.toLowerCase().contains('atmos') == true ? 'TrueHD Atmos' : 'TrueHD';
  return null;
}

bool _isTextCodec(String codec) => const {'srt', 'ass', 'ssa', 'vtt', 'ttml', 'mov_text', 'sub', 'smi'}.contains(codec);
