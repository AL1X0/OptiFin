import 'package:flutter/foundation.dart';

enum LogLevel {
  debug('D'),
  info('I'),
  warning('W'),
  error('E');

  const LogLevel(this.letter);
  final String letter;
}

class LogEntry {
  const LogEntry(this.time, this.level, this.tag, this.message);

  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;

  String format() {
    final t = time.toIso8601String().substring(11, 23);
    return '$t ${level.letter}/$tag: $message';
  }
}

/// Journal de l'application, en mémoire (tampon circulaire).
///
/// Affiché et copiable depuis Paramètres › Journaux (mode debug). Les secrets
/// (tokens, clés d'API, mots de passe) sont masqués **à l'écriture** : rien de
/// sensible ne peut être copié-collé par erreur.
class AppLog extends ChangeNotifier {
  AppLog._();

  static final instance = AppLog._();

  static const capacity = 3000;

  final _entries = <LogEntry>[];

  /// Mode debug : journalise aussi les niveaux `debug` (requêtes réussies, logs mpv).
  bool verbose = false;

  List<LogEntry> get entries => List.unmodifiable(_entries);

  static void d(String tag, String message) => instance.add(LogLevel.debug, tag, message);
  static void i(String tag, String message) => instance.add(LogLevel.info, tag, message);
  static void w(String tag, String message) => instance.add(LogLevel.warning, tag, message);
  static void e(String tag, String message, [Object? error, StackTrace? stack]) => instance.add(
        LogLevel.error,
        tag,
        [message, if (error != null) '$error', if (stack != null) _shortStack(stack)].join('\n'),
      );

  void add(LogLevel level, String tag, String message) {
    if (level == LogLevel.debug && !verbose) return;
    _entries.add(LogEntry(DateTime.now(), level, tag, redact(message)));
    if (_entries.length > capacity) _entries.removeRange(0, _entries.length - capacity);
    if (kDebugMode) debugPrint('[$tag] ${_entries.last.message}');
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  /// Texte complet à copier (niveau minimal optionnel).
  String export({LogLevel minLevel = LogLevel.debug}) =>
      _entries.where((e) => e.level.index >= minLevel.index).map((e) => e.format()).join('\n');

  static final _patterns = <(RegExp, String)>[
    (RegExp(r'Token="[^"]*"'), 'Token="***"'),
    (RegExp(r'(api_key|ApiKey|apikey|api-key)=([^&\s"]+)', caseSensitive: false), r'$1=***'),
    (RegExp(r'(X-Emby-Token|X-MediaBrowser-Token)["\s:=]+[^\s",}]+', caseSensitive: false), r'$1: ***'),
    (RegExp(r'"(AccessToken|Pw|Password|Secret)"\s*:\s*"[^"]*"', caseSensitive: false), r'"$1":"***"'),
  ];

  /// Masque les secrets connus dans un texte.
  static String redact(String input) {
    var out = input;
    for (final (pattern, replacement) in _patterns) {
      out = out.replaceAllMapped(pattern, (m) {
        var r = replacement;
        for (var g = 1; g <= m.groupCount; g++) {
          r = r.replaceAll('\$$g', m.group(g) ?? '');
        }
        return r;
      });
    }
    return out;
  }

  static String _shortStack(StackTrace stack) => stack.toString().split('\n').take(8).join('\n');
}
