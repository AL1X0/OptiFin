/// Profils d'appareil envoyés au serveur dans `PlaybackInfo`.
///
/// Ils décident ce que le serveur accepte d'envoyer tel quel (Direct Play), de
/// remuxer (Direct Stream) ou de transcoder. Un profil par moteur : mpv (lit
/// presque tout) et natif (construit à partir des capacités mesurées de
/// l'appareil). Construits en JSON Jellyfin (plus lisible et testable que les
/// constructeurs générés).
library;

import '../domain/device_capabilities.dart';
import '../domain/engine_selector.dart';
import '../domain/source_profile.dart';

/// Débit max par défaut (réglable dans les Paramètres, Wi-Fi / cellulaire).
const defaultMaxStreamingBitrate = 120000000;

/// Formats de sous-titres texte que le serveur peut livrer en fichier séparé.
const _textSubtitleFormats = ['srt', 'subrip', 'ass', 'ssa', 'vtt', 'webvtt', 'ttml', 'sub', 'smi'];

/// Formats image : jamais extraits (livrés intégrés, ou incrustés si transcodage).
const _bitmapSubtitleFormats = ['pgs', 'pgssub', 'dvdsub', 'dvbsub', 'vobsub', 'xsub'];

/// Profil libmpv : lit pratiquement tout en Direct Play (décodage matériel
/// VideoToolbox / MediaCodec, repli logiciel ffmpeg). Le transcodage ne sert
/// qu'en cas de débit insuffisant : HLS H.264/HEVC + AAC/AC3.
Map<String, Object?> mpvDeviceProfile({int maxStreamingBitrate = defaultMaxStreamingBitrate}) => {
  'Name': 'OptiFin (mpv)',
  'MaxStreamingBitrate': maxStreamingBitrate,
  'MaxStaticBitrate': 400000000,
  'MusicStreamingTranscodingBitrate': 320000,
  'DirectPlayProfiles': [
    {
      'Type': 'Video',
      'Container': 'mkv,mp4,m4v,mov,webm,avi,ts,m2ts,mts,mpegts,wmv,asf,flv,3gp,ogv,ogm,vob,mpg,mpeg,dvr-ms,wtv',
    },
    {'Type': 'Audio', 'Container': 'mp3,aac,m4a,m4b,flac,alac,wav,ogg,oga,opus,wma,ape,wv,dsf,dff,mka,webma'},
  ],
  'TranscodingProfiles': [
    {
      'Type': 'Video',
      'Container': 'ts',
      'Protocol': 'hls',
      'Context': 'Streaming',
      'VideoCodec': 'hevc,h264',
      'AudioCodec': 'aac,ac3,eac3,mp3,opus',
      'MaxAudioChannels': '8',
      'MinSegments': 1,
      'BreakOnNonKeyFrames': true,
    },
    {'Type': 'Audio', 'Container': 'mp3', 'Protocol': 'http', 'Context': 'Streaming', 'AudioCodec': 'mp3'},
  ],
  'ContainerProfiles': <Object?>[],
  'CodecProfiles': <Object?>[],
  'SubtitleProfiles': [
    // Direct Play : mpv lit toutes les pistes intégrées (libass pour ASS, rendu PGS natif).
    for (final f in [..._textSubtitleFormats, ..._bitmapSubtitleFormats]) {'Format': f, 'Method': 'Embed'},
    // Transcodage : sous-titres texte servis à part (rendu mpv), image → incrustés par le serveur.
    for (final f in _textSubtitleFormats) {'Format': f, 'Method': 'External'},
    for (final f in _bitmapSubtitleFormats) {'Format': f, 'Method': 'Encode'},
  ],
};

/// Profil du lecteur natif (AVPlayer / Media3), dérivé des capacités mesurées.
///
/// - Direct Play limité aux conteneurs, codecs et gammes dynamiques réellement lus.
/// - Transcodage / remux en HLS fMP4 : seul format qui transporte HEVC, HDR10 et
///   Dolby Vision vers AVPlayer ; la vidéo est copiée quand elle est compatible.
/// - Sous-titres texte toujours servis à part en WebVTT (dessinés par OptiFin),
///   sous-titres image incrustés.
Map<String, Object?> nativeDeviceProfile(
  DeviceCapabilities caps, {
  int maxStreamingBitrate = defaultMaxStreamingBitrate,
}) {
  final video = [
    for (final c in const ['hevc', 'h264', 'av1', 'vp9'])
      if (c == 'h264' || caps.videoCodecs.contains(c)) c,
  ];
  final audio = [
    for (final c in const ['aac', 'mp3', 'ac3', 'eac3', 'flac', 'alac', 'opus', 'vorbis', 'truehd', 'dts'])
      if (c == 'aac' || caps.audioCodecs.contains(c)) c,
  ];
  // HLS fMP4 : combinaisons sûres pour les deux plateformes.
  final hlsVideo = [if (caps.videoCodecs.contains('hevc')) 'hevc', 'h264'];
  final hlsAudio = [
    'aac',
    for (final c in const ['eac3', 'ac3', 'mp3'])
      if (caps.audioCodecs.contains(c)) c,
  ];
  final hevcRanges = nativeVideoRangeTypes(caps);

  return {
    'Name': 'OptiFin (${caps.platform == DevicePlatform.ios ? 'AVPlayer' : 'Media3'})',
    'MaxStreamingBitrate': maxStreamingBitrate,
    'MaxStaticBitrate': 400000000,
    'MusicStreamingTranscodingBitrate': 320000,
    'DirectPlayProfiles': [
      {
        'Type': 'Video',
        'Container': caps.containers.join(','),
        'VideoCodec': video.join(','),
        'AudioCodec': audio.join(','),
      },
      {'Type': 'Audio', 'Container': 'mp3,aac,m4a,m4b,flac,alac,wav,opus,ogg'},
    ],
    'TranscodingProfiles': [
      {
        'Type': 'Video',
        'Container': 'mp4',
        'Protocol': 'hls',
        'Context': 'Streaming',
        'VideoCodec': hlsVideo.join(','),
        'AudioCodec': hlsAudio.join(','),
        'MaxAudioChannels': '8',
        'MinSegments': 2,
        'BreakOnNonKeyFrames': true,
      },
      {'Type': 'Audio', 'Container': 'mp3', 'Protocol': 'http', 'Context': 'Streaming', 'AudioCodec': 'mp3'},
    ],
    'ContainerProfiles': <Object?>[],
    'CodecProfiles': [
      // Gammes dynamiques : un Dolby Vision non supporté est remuxé par le serveur
      // vers sa couche de base HDR10 plutôt qu'envoyé tel quel (image fausse).
      for (final codec in const ['hevc', 'av1'])
        {
          'Type': 'Video',
          'Codec': codec,
          'Conditions': [
            {
              'Condition': 'EqualsAny',
              'Property': 'VideoRangeType',
              'Value': hevcRanges.join('|'),
              'IsRequired': false,
            },
            if (codec == 'hevc' && !caps.hevcMain10)
              {'Condition': 'LessThanEqual', 'Property': 'VideoBitDepth', 'Value': '8', 'IsRequired': false},
          ],
        },
      {
        'Type': 'Video',
        'Codec': 'h264',
        'Conditions': [
          {'Condition': 'LessThanEqual', 'Property': 'VideoBitDepth', 'Value': '8', 'IsRequired': false},
        ],
      },
      {
        'Type': 'Video',
        'Conditions': [
          {'Condition': 'LessThanEqual', 'Property': 'Width', 'Value': '${caps.maxWidth}', 'IsRequired': false},
        ],
      },
    ],
    'SubtitleProfiles': [
      // Un seul format externe : le serveur convertit SRT, ASS, mov_text… en WebVTT.
      {'Format': 'vtt', 'Method': 'External'},
      for (final f in _bitmapSubtitleFormats) {'Format': f, 'Method': 'Encode'},
    ],
  };
}

/// Valeurs Jellyfin de `VideoRangeType` que le lecteur natif affiche correctement.
List<String> nativeVideoRangeTypes(DeviceCapabilities caps) {
  final hdr10 = caps.ranges.contains(DynamicRange.hdr10);
  final hlg = caps.ranges.contains(DynamicRange.hlg);
  final dv = caps.supportsDolbyVision;
  return [
    'SDR',
    if (hdr10) ...['HDR10', 'HDR10Plus', 'DOVIInvalid'],
    if (hlg) 'HLG',
    if (dv) ...[
      'DOVI',
      'DOVIWithSDR',
      if (hdr10) ...['DOVIWithHDR10', 'DOVIWithHDR10Plus', 'DOVIWithEL', 'DOVIWithELHDR10Plus'],
      if (hlg) 'DOVIWithHLG',
    ],
  ];
}

/// Options de la requête `PlaybackInfo` pour une décision de l'EngineSelector.
class PlaybackRequestOptions {
  const PlaybackRequestOptions({
    required this.deviceProfile,
    this.enableDirectPlay = true,
    this.enableDirectStream = true,
    this.allowVideoStreamCopy = true,
  });

  final Map<String, Object?> deviceProfile;
  final bool enableDirectPlay;
  final bool enableDirectStream;
  final bool allowVideoStreamCopy;

  static PlaybackRequestOptions mpv(int maxBitrate) =>
      PlaybackRequestOptions(deviceProfile: mpvDeviceProfile(maxStreamingBitrate: maxBitrate));

  factory PlaybackRequestOptions.forDecision(EngineDecision d, DeviceCapabilities caps, int maxBitrate) {
    final profile = d.isNative
        ? nativeDeviceProfile(caps, maxStreamingBitrate: maxBitrate)
        : mpvDeviceProfile(maxStreamingBitrate: maxBitrate);
    return switch (d.delivery) {
      Delivery.directPlay => PlaybackRequestOptions(deviceProfile: profile),
      // Remux : la vidéo est copiée (HDR/DV intacts), seul l'emballage (et l'audio si besoin) change.
      Delivery.remux => PlaybackRequestOptions(deviceProfile: profile, enableDirectPlay: false),
      Delivery.transcode => PlaybackRequestOptions(
        deviceProfile: profile,
        enableDirectPlay: false,
        enableDirectStream: false,
        // Incrustation ou codec illisible : la vidéo doit être ré-encodée.
        allowVideoStreamCopy: !d.reencodeVideo,
      ),
    };
  }
}
