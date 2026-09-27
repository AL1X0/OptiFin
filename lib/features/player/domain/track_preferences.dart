import '../../settings/domain/app_settings.dart';
import 'playback_plan.dart';

/// Codes de langue équivalents (ISO 639-2 B/T, 639-1) ramenés à une forme unique.
const _aliases = <String, String>{
  'fr': 'fre',
  'fra': 'fre',
  'fre': 'fre',
  'en': 'eng',
  'eng': 'eng',
  'es': 'spa',
  'spa': 'spa',
  'de': 'ger',
  'deu': 'ger',
  'ger': 'ger',
  'it': 'ita',
  'ita': 'ita',
  'pt': 'por',
  'por': 'por',
  'ja': 'jpn',
  'jpn': 'jpn',
  'ko': 'kor',
  'kor': 'kor',
  'zh': 'chi',
  'zho': 'chi',
  'chi': 'chi',
  'ru': 'rus',
  'rus': 'rus',
  'ar': 'ara',
  'ara': 'ara',
  'nl': 'dut',
  'nld': 'dut',
  'dut': 'dut',
};

String? normalizeLanguage(String? code) {
  if (code == null || code.isEmpty) return null;
  final c = code.toLowerCase().split(RegExp('[-_]')).first;
  return _aliases[c] ?? c;
}

/// Pistes à utiliser selon les préférences locales. Pur, testé.
///
/// Retourne (audioIndex, subtitleIndex) ; les valeurs du plan sont conservées
/// quand aucune préférence ne s'applique (le serveur a déjà appliqué les
/// préférences du compte Jellyfin).
(int?, int?) preferredTracks(PlaybackPlan plan, AppSettings settings) {
  var audio = plan.audioIndex;
  final audioLang = normalizeLanguage(settings.audioLanguage);
  if (audioLang != null) {
    final matches = plan.audioTracks.where((t) => normalizeLanguage(t.language) == audioLang).toList();
    if (matches.isNotEmpty && !matches.any((t) => t.index == audio)) {
      audio = (matches.where((t) => t.isDefault).firstOrNull ?? matches.first).index;
    }
  }

  final subLang = normalizeLanguage(settings.subtitleLanguage);
  final subs = plan.subtitleTracks;
  List<MediaTrack> inLang(Iterable<MediaTrack> tracks) =>
      subLang == null ? tracks.toList() : tracks.where((t) => normalizeLanguage(t.language) == subLang).toList();

  final int? subtitle = switch (settings.subtitleMode) {
    SubtitleMode.server => plan.subtitleIndex,
    SubtitleMode.none => null,
    SubtitleMode.always =>
      (inLang(subs.where((t) => !t.isForced)).firstOrNull ?? inLang(subs).firstOrNull)?.index ?? plan.subtitleIndex,
    SubtitleMode.forcedOnly => inLang(subs.where((t) => t.isForced)).firstOrNull?.index,
  };
  return (audio, subtitle);
}
