import 'dart:convert';

import 'source_profile.dart';

enum DevicePlatform { ios, android, other }

/// Ce que le lecteur **natif** de l'appareil sait décoder et afficher.
///
/// Mesuré au premier lancement d'une lecture par le plugin natif (décodeurs
/// matériels, modes HDR de l'écran, profils Dolby Vision), puis mis en cache.
/// libmpv, lui, lit tout ; mais il s'appuie sur les mêmes décodeurs matériels :
/// un codec sans décodeur matériel y est décodé en logiciel (lent en 4K).
class DeviceCapabilities {
  const DeviceCapabilities({
    required this.platform,
    this.nativeAvailable = true,
    this.model,
    this.osVersion,
    this.videoCodecs = const {'h264'},
    this.hevcMain10 = false,
    this.ranges = const {DynamicRange.sdr},
    this.dolbyVisionProfiles = const {},
    this.audioCodecs = const {'aac', 'mp3'},
    this.containers = const {'mp4', 'm4v', 'mov'},
    this.maxWidth = 1920,
    this.pictureInPicture = false,
    this.airPlay = false,
  });

  final DevicePlatform platform;

  /// false si le plugin natif est absent (tests, plateforme non gérée) : tout passe par mpv.
  final bool nativeAvailable;
  final String? model;
  final String? osVersion;

  /// Codecs vidéo à décodage **matériel** : h264, hevc, av1, vp9.
  final Set<String> videoCodecs;

  /// HEVC 10 bits (Main10) décodable : prérequis du HDR10 et du Dolby Vision.
  final bool hevcMain10;

  /// Gammes dynamiques lisibles par le lecteur natif (affichées ou converties
  /// proprement par le système). SDR toujours présent.
  final Set<DynamicRange> ranges;

  /// Profils Dolby Vision décodables nativement (vide = pas de DV).
  final Set<int> dolbyVisionProfiles;

  /// Codecs audio lisibles par le lecteur natif (aac, mp3, ac3, eac3, flac, alac, opus, truehd, dts…).
  final Set<String> audioCodecs;

  /// Conteneurs lus en lecture directe par le lecteur natif.
  final Set<String> containers;

  /// Largeur max décodable en matériel (3840 pour la 4K).
  final int maxWidth;

  /// Picture-in-Picture disponible (iOS : lecteur natif ; Android : toute l'activité).
  final bool pictureInPicture;

  /// AirPlay (iOS, lecteur natif).
  final bool airPlay;


  bool get supportsDolbyVision => dolbyVisionProfiles.isNotEmpty;

  /// Profil par défaut, prudent, si la détection échoue.
  factory DeviceCapabilities.fallback(DevicePlatform platform) => switch (platform) {
    DevicePlatform.ios => const DeviceCapabilities(
      platform: DevicePlatform.ios,
      videoCodecs: {'h264', 'hevc'},
      hevcMain10: true,
      ranges: {DynamicRange.sdr, DynamicRange.hdr10, DynamicRange.hlg},
      audioCodecs: {'aac', 'mp3', 'ac3', 'eac3', 'alac', 'flac'},
      containers: {'mp4', 'm4v', 'mov'},
      maxWidth: 3840,
    ),
    DevicePlatform.android => const DeviceCapabilities(
      platform: DevicePlatform.android,
      videoCodecs: {'h264', 'hevc', 'vp9'},
      audioCodecs: {'aac', 'mp3', 'flac', 'opus', 'vorbis'},
      containers: {'mp4', 'm4v', 'mov', 'mkv', 'webm', 'ts', 'mpegts'},
    ),
    DevicePlatform.other => const DeviceCapabilities(platform: DevicePlatform.other, nativeAvailable: false),
  };

  /// Depuis la réponse du plugin natif (clés stables, valeurs tolérées si absentes).
  factory DeviceCapabilities.fromJson(Map<String, Object?> json) {
    Set<String> strings(String key, Set<String> fallback) {
      final v = json[key];
      return v is List
          ? {
              for (final e in v)
                if (e is String) normalizeCodec(e),
            }
          : fallback;
    }

    final platform = switch (json['platform']) {
      'ios' => DevicePlatform.ios,
      'android' => DevicePlatform.android,
      _ => DevicePlatform.other,
    };
    final base = DeviceCapabilities.fallback(platform);
    final ranges = json['ranges'];
    final dv = json['dolbyVisionProfiles'];
    final containers = json['containers'];
    return DeviceCapabilities(
      platform: platform,
      nativeAvailable: json['nativeAvailable'] != false && platform != DevicePlatform.other,
      model: json['model'] as String?,
      osVersion: json['osVersion'] as String?,
      videoCodecs: strings('videoCodecs', base.videoCodecs),
      hevcMain10: json['hevcMain10'] is bool ? json['hevcMain10']! as bool : base.hevcMain10,
      ranges: ranges is List
          ? {DynamicRange.sdr, for (final r in ranges) ?DynamicRange.values.where((d) => d.name == r).firstOrNull}
          : base.ranges,
      dolbyVisionProfiles: dv is List
          ? {
              for (final p in dv)
                if (p is int) p,
            }
          : base.dolbyVisionProfiles,
      audioCodecs: strings('audioCodecs', base.audioCodecs),
      containers: containers is List
          ? {
              for (final c in containers)
                if (c is String) c.toLowerCase(),
            }
          : base.containers,
      maxWidth: json['maxWidth'] is int ? json['maxWidth']! as int : base.maxWidth,
      pictureInPicture: json['pictureInPicture'] == true,
      airPlay: json['airPlay'] == true,
    );
  }

  Map<String, Object?> toJson() => {
    'platform': platform.name,
    'nativeAvailable': nativeAvailable,
    'model': model,
    'osVersion': osVersion,
    'videoCodecs': videoCodecs.toList(),
    'hevcMain10': hevcMain10,
    'ranges': [for (final r in ranges) r.name],
    'dolbyVisionProfiles': dolbyVisionProfiles.toList(),
    'audioCodecs': audioCodecs.toList(),
    'containers': containers.toList(),
    'maxWidth': maxWidth,
    'pictureInPicture': pictureInPicture,
    'airPlay': airPlay,
  };

  String toJsonString() => jsonEncode(toJson());

  static DeviceCapabilities? tryParse(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      return json is Map<String, Object?> ? DeviceCapabilities.fromJson(json) : null;
    } catch (_) {
      return null;
    }
  }

  /// Résumé lisible (paramètres, journaux).
  String get summary => [
    '${platform.name}${model == null ? '' : ' $model'}${osVersion == null ? '' : ' $osVersion'}',
    'vidéo ${videoCodecs.join('/')}${hevcMain10 ? ' (HEVC 10 bits)' : ''}',
    'gammes ${ranges.map((r) => r.label).join('/')}',
    if (supportsDolbyVision) 'DV p${dolbyVisionProfiles.join('/')}',
    'audio ${audioCodecs.join('/')}',
    'conteneurs ${containers.join('/')}',
    'max ${maxWidth}px',
  ].join(' · ');
}
