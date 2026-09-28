import 'dart:convert';

import '../../player/domain/engine_selector.dart';
import '../../player/domain/playback_engine.dart';

/// Comportement des sous-titres au démarrage d'une lecture.
enum SubtitleMode {
  server('Réglage du serveur'),
  always('Toujours'),
  forcedOnly('Forcés uniquement'),
  none('Jamais');

  const SubtitleMode(this.label);
  final String label;
}

/// Langues proposées (code ISO 639-2 utilisé par Jellyfin).
const preferredLanguages = <String, String>{
  'fre': 'Français',
  'eng': 'Anglais',
  'spa': 'Espagnol',
  'ger': 'Allemand',
  'ita': 'Italien',
  'por': 'Portugais',
  'jpn': 'Japonais',
  'kor': 'Coréen',
  'chi': 'Chinois',
  'rus': 'Russe',
  'ara': 'Arabe',
  'dut': 'Néerlandais',
};

/// Débits proposés (bits/s). 0 = pas de limite côté client (le serveur plafonne).
const bitrateChoices = <int, String>{
  0: 'Maximum',
  120000000: '120 Mb/s (4K)',
  60000000: '60 Mb/s',
  40000000: '40 Mb/s (1080p)',
  20000000: '20 Mb/s',
  10000000: '10 Mb/s (720p)',
  4000000: '4 Mb/s',
  1500000: '1,5 Mb/s',
};

class AppSettings {
  const AppSettings({
    this.debugMode = false,
    this.maxBitrateWifi = 0,
    this.maxBitrateCellular = 10000000,
    this.audioLanguage,
    this.subtitleLanguage,
    this.subtitleMode = SubtitleMode.server,
    this.subtitleScale = 1,
    this.subtitleBackground = SubtitleBackground.none,
    this.enginePreference = EnginePreference.auto,
    this.imageSubtitles = ImageSubtitlePolicy.auto,
    this.autoSkipSegments = false,
    this.autoPlayNext = true,
  });

  final bool debugMode;
  final int maxBitrateWifi;
  final int maxBitrateCellular;

  /// null = choix du serveur (préférences du compte Jellyfin).
  final String? audioLanguage;
  final String? subtitleLanguage;
  final SubtitleMode subtitleMode;
  final double subtitleScale;
  final SubtitleBackground subtitleBackground;

  /// Moteur de lecture : automatique (EngineSelector), natif ou mpv.
  final EnginePreference enginePreference;

  /// Sous-titres image sur une vidéo destinée au lecteur natif : mpv ou incrustation.
  final ImageSubtitlePolicy imageSubtitles;

  /// Passe automatiquement intros, récapitulatifs et aperçus (segments Jellyfin).
  final bool autoSkipSegments;

  /// Enchaîne l'épisode suivant après un compte à rebours.
  final bool autoPlayNext;

  SubtitleStyle get subtitleStyle => SubtitleStyle(scale: subtitleScale, background: subtitleBackground);

  AppSettings copyWith({
    bool? debugMode,
    int? maxBitrateWifi,
    int? maxBitrateCellular,
    String? Function()? audioLanguage,
    String? Function()? subtitleLanguage,
    SubtitleMode? subtitleMode,
    double? subtitleScale,
    SubtitleBackground? subtitleBackground,
    EnginePreference? enginePreference,
    ImageSubtitlePolicy? imageSubtitles,
    bool? autoSkipSegments,
    bool? autoPlayNext,
  }) => AppSettings(
    debugMode: debugMode ?? this.debugMode,
    maxBitrateWifi: maxBitrateWifi ?? this.maxBitrateWifi,
    maxBitrateCellular: maxBitrateCellular ?? this.maxBitrateCellular,
    audioLanguage: audioLanguage != null ? audioLanguage() : this.audioLanguage,
    subtitleLanguage: subtitleLanguage != null ? subtitleLanguage() : this.subtitleLanguage,
    subtitleMode: subtitleMode ?? this.subtitleMode,
    subtitleScale: subtitleScale ?? this.subtitleScale,
    subtitleBackground: subtitleBackground ?? this.subtitleBackground,
    enginePreference: enginePreference ?? this.enginePreference,
    imageSubtitles: imageSubtitles ?? this.imageSubtitles,
    autoSkipSegments: autoSkipSegments ?? this.autoSkipSegments,
    autoPlayNext: autoPlayNext ?? this.autoPlayNext,
  );

  Map<String, Object?> toJson() => {
    'v': 1,
    'debugMode': debugMode,
    'maxBitrateWifi': maxBitrateWifi,
    'maxBitrateCellular': maxBitrateCellular,
    'audioLanguage': audioLanguage,
    'subtitleLanguage': subtitleLanguage,
    'subtitleMode': subtitleMode.name,
    'subtitleScale': subtitleScale,
    'subtitleBackground': subtitleBackground.name,
    'enginePreference': enginePreference.name,
    'imageSubtitles': imageSubtitles.name,
    'autoSkipSegments': autoSkipSegments,
    'autoPlayNext': autoPlayNext,
  };

  /// Lecture tolérante : une clé absente ou invalide reprend sa valeur par défaut
  /// (réglages écrits par une version antérieure de l'app).
  static AppSettings fromJsonString(String? raw) {
    const d = AppSettings();
    if (raw == null) return d;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      T? pick<T>(String k) => j[k] is T ? j[k] as T : null;
      return AppSettings(
        debugMode: pick<bool>('debugMode') ?? d.debugMode,
        maxBitrateWifi: pick<int>('maxBitrateWifi') ?? d.maxBitrateWifi,
        maxBitrateCellular: pick<int>('maxBitrateCellular') ?? d.maxBitrateCellular,
        audioLanguage: pick<String>('audioLanguage'),
        subtitleLanguage: pick<String>('subtitleLanguage'),
        subtitleMode: SubtitleMode.values.where((m) => m.name == j['subtitleMode']).firstOrNull ?? d.subtitleMode,
        subtitleScale: (j['subtitleScale'] is num) ? (j['subtitleScale'] as num).toDouble() : d.subtitleScale,
        subtitleBackground:
            SubtitleBackground.values.where((b) => b.name == j['subtitleBackground']).firstOrNull ??
            d.subtitleBackground,
        enginePreference:
            EnginePreference.values.where((e) => e.name == j['enginePreference']).firstOrNull ?? d.enginePreference,
        imageSubtitles:
            ImageSubtitlePolicy.values.where((e) => e.name == j['imageSubtitles']).firstOrNull ?? d.imageSubtitles,
        autoSkipSegments: pick<bool>('autoSkipSegments') ?? d.autoSkipSegments,
        autoPlayNext: pick<bool>('autoPlayNext') ?? d.autoPlayNext,
      );
    } catch (_) {
      return d;
    }
  }

  String toJsonString() => jsonEncode(toJson());
}
