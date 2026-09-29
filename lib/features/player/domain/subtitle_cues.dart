/// Sous-titres texte (WebVTT / SRT) dessinés par OptiFin au-dessus du lecteur natif.
///
/// Le serveur convertit toutes les pistes texte (SRT, ASS, mov_text…) en WebVTT ;
/// le SRT reste accepté (fichiers externes servis tels quels).
library;

class SubtitleCue {
  const SubtitleCue(this.start, this.end, this.text);

  final Duration start;
  final Duration end;

  /// Texte brut, balises retirées, lignes séparées par `\n`.
  final String text;

  @override
  String toString() => '[$start → $end] $text';
}

/// Analyse un fichier WebVTT ou SRT. Tolérant : un bloc illisible est ignoré.
List<SubtitleCue> parseSubtitles(String raw) {
  final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceFirst('﻿', '');
  final cues = <SubtitleCue>[];
  for (final block in text.split(RegExp(r'\n{2,}'))) {
    final lines = block.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final timing = lines.indexWhere((l) => l.contains('-->'));
    if (timing < 0) continue; // en-tête WEBVTT, NOTE, STYLE, REGION…
    final parts = lines[timing].split('-->');
    final start = _time(parts[0]);
    // Après l'heure de fin, WebVTT peut ajouter des réglages (« line:90% align:center »).
    final end = _time(parts[1].trim().split(RegExp(r'\s+')).first);
    if (start == null || end == null || end <= start) continue;
    final body = lines.skip(timing + 1).map(_clean).where((l) => l.isNotEmpty).join('\n');
    if (body.isNotEmpty) cues.add(SubtitleCue(start, end, body));
  }
  cues.sort((a, b) => a.start.compareTo(b.start));
  return cues;
}

final _timeRe = RegExp(r'^(?:(\d+):)?(\d{1,2}):(\d{1,2})[.,](\d{1,3})$');

Duration? _time(String raw) {
  final m = _timeRe.firstMatch(raw.trim());
  if (m == null) return null;
  final ms = m.group(4)!.padRight(3, '0');
  return Duration(
    hours: int.parse(m.group(1) ?? '0'),
    minutes: int.parse(m.group(2)!),
    seconds: int.parse(m.group(3)!),
    milliseconds: int.parse(ms),
  );
}

final _tags = RegExp(r'<[^>]*>|\{\\[^}]*\}');

String _clean(String line) => line
    .replaceAll(_tags, '')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&nbsp;', ' ')
    .replaceAll(r'\N', '\n')
    .trim();

/// Recherche des cues actives à un instant donné (liste triée, recherche dichotomique).
class CueTrack {
  CueTrack(this.cues) : _maxLength = _longest(cues);

  final List<SubtitleCue> cues;
  final Duration _maxLength;

  static Duration _longest(List<SubtitleCue> cues) =>
      cues.fold(Duration.zero, (m, c) => c.end - c.start > m ? c.end - c.start : m);

  /// Texte à afficher à [position] (plusieurs cues simultanées : empilées), ou null.
  String? textAt(Duration position) {
    if (cues.isEmpty) return null;
    // Premier indice dont le début est > position.
    var lo = 0;
    var hi = cues.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (cues[mid].start <= position) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final active = <String>[];
    for (var i = lo - 1; i >= 0; i--) {
      final c = cues[i];
      if (position - c.start > _maxLength) break;
      if (position < c.end) active.add(c.text);
    }
    return active.isEmpty ? null : active.reversed.join('\n');
  }

  /// Prochain instant après [position] où le texte affiché change (début d'une cue ou
  /// fin d'une cue active), ou null s'il n'y en a plus.
  Duration? nextChangeAfter(Duration position) {
    if (cues.isEmpty) return null;
    var lo = 0;
    var hi = cues.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (cues[mid].start <= position) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    Duration? next = lo < cues.length ? cues[lo].start : null;
    for (var i = lo - 1; i >= 0; i--) {
      final c = cues[i];
      if (position - c.start > _maxLength) break;
      if (c.end > position && (next == null || c.end < next)) next = c.end;
    }
    return next;
  }
}
