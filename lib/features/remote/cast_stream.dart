import '../player/data/device_profiles.dart';
import '../player/domain/playback_plan.dart';

/// Ce qu'un Chromecast lit à coup sûr : H.264 et AAC, en MP4 tel quel ou en HLS préparé par le
/// serveur. Pas de sous-titres dans cette première version.
Map<String, Object?> castDeviceProfile({int maxStreamingBitrate = 20000000}) => {
  'Name': 'OptiFin (Chromecast)',
  'MaxStreamingBitrate': maxStreamingBitrate,
  'MaxStaticBitrate': maxStreamingBitrate,
  'DirectPlayProfiles': [
    {'Type': 'Video', 'Container': 'mp4,m4v', 'VideoCodec': 'h264', 'AudioCodec': 'aac,mp3'},
  ],
  'TranscodingProfiles': [
    {
      'Type': 'Video',
      'Container': 'ts',
      'Protocol': 'hls',
      'Context': 'Streaming',
      'VideoCodec': 'h264',
      'AudioCodec': 'aac',
      'MaxAudioChannels': '2',
      'MinSegments': 1,
      'BreakOnNonKeyFrames': true,
    },
  ],
  'ContainerProfiles': const <Object>[],
  'CodecProfiles': const <Object>[],
  'SubtitleProfiles': const <Object>[],
};

PlaybackRequestOptions castRequestOptions() => PlaybackRequestOptions(deviceProfile: castDeviceProfile());

/// Adresse donnée au Chromecast. Il ne sait pas envoyer d'en-tête d'authentification : le jeton passe
/// dans l'adresse, ce qui n'est fait que pour lui (jamais pour le lecteur de l'appli) et jamais journalisé.
Uri castUrl(PlaybackPlan plan, String token) =>
    plan.streamUrl.replace(queryParameters: {...plan.streamUrl.queryParameters, 'api_key': token});

String castContentType(PlaybackPlan plan) =>
    plan.method == PlayMethod.directPlay ? 'video/mp4' : 'application/x-mpegURL';
