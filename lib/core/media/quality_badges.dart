import 'media_item.dart';

/// Calcule les badges qualité affichés sur une fiche : résolution, dynamique, audio.
///
/// Ordre : résolution → HDR/DV → audio immersif/HD → canaux. Un seul badge par
/// catégorie, le plus « premium » gagne (DV > HDR10+ > HDR10 > HLG ; Atmos > DTS:X > TrueHD…).
List<String> qualityBadges(List<StreamSummary> streams) {
  final video = streams.where((s) => s.isVideo).firstOrNull;
  final audios = streams.where((s) => !s.isVideo).toList();
  final badges = <String>[];

  if (video != null) {
    final res = resolutionLabel(video.width, video.height);
    if (res != null) badges.add(res);
    switch (video.videoRange) {
      case VideoRange.dolbyVision:
        badges.add('Dolby Vision');
      case VideoRange.hdr10Plus:
        badges.add('HDR10+');
      case VideoRange.hdr10:
        badges.add('HDR10');
      case VideoRange.hlg:
        badges.add('HLG');
      case VideoRange.sdr:
        break;
    }
  }

  final audio = _bestAudioLabel(audios);
  if (audio != null) badges.add(audio);

  final maxChannels = audios.map((a) => a.channels ?? 0).fold(0, (a, b) => a > b ? a : b);
  final channels = channelsLabel(maxChannels);
  if (channels != null) badges.add(channels);

  return badges;
}

/// 4K / 1080p / 720p / SD, en tolérant les formats recadrés (2.39:1 → hauteur réduite).
String? resolutionLabel(int? width, int? height) {
  if (width == null || height == null || width <= 0 || height <= 0) return null;
  if (width >= 3200 || height >= 2000) return '4K';
  if (width >= 1800 || height >= 1000) return '1080p';
  if (width >= 1200 || height >= 700) return '720p';
  return 'SD';
}

String? channelsLabel(int channels) => switch (channels) {
  <= 0 => null,
  1 => null,
  2 => null, // stéréo : pas de badge, c'est la norme
  6 => '5.1',
  8 => '7.1',
  _ => null,
};

String? _bestAudioLabel(List<StreamSummary> audios) {
  int rank(String label) =>
      const ['Atmos', 'DTS:X', 'TrueHD', 'DTS-HD MA', 'DTS', 'Dolby Digital+', 'Dolby Digital'].indexOf(label);

  String? best;
  for (final a in audios) {
    final label = audioLabel(a);
    if (label == null) continue;
    if (best == null || rank(label) < rank(best)) best = label;
  }
  return best;
}

String? audioLabel(StreamSummary a) {
  if (a.spatial == SpatialAudio.atmos) return 'Atmos';
  if (a.spatial == SpatialAudio.dtsX) return 'DTS:X';
  final profile = (a.profile ?? '').toLowerCase();
  return switch (a.codec) {
    'truehd' || 'mlp' => 'TrueHD',
    'dts' || 'dca' when profile.contains('ma') || profile.contains('hd') => 'DTS-HD MA',
    'dts' || 'dca' => 'DTS',
    'eac3' => 'Dolby Digital+',
    'ac3' => 'Dolby Digital',
    _ => null,
  };
}
