/// Profils d'appareil envoyés au serveur dans `PlaybackInfo`.
///
/// Ils décident ce que le serveur accepte d'envoyer tel quel (Direct Play), de
/// remuxer (Direct Stream) ou de transcoder. Construits en JSON Jellyfin (plus
/// lisible et testable que les constructeurs générés).
library;

/// Débit max par défaut (réglable en phase Paramètres, Wi-Fi / cellulaire).
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
