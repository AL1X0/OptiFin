import 'dart:ui' show PlatformDispatcher;

import 'english_texts.dart';

/// Langue de l'appli : français si l'appareil est en français, anglais sinon. La phrase française
/// reste dans le code et sert de clé au dictionnaire [englishTexts] (un test vérifie qu'elle y figure).
abstract final class L {
  static bool isEnglish = PlatformDispatcher.instance.locale.languageCode != 'fr';

  static String t(String french) => isEnglish ? englishTexts[french] ?? french : french;

  /// Phrase avec variables : « Aucun résultat pour « {0} ». ».
  static String f(String french, List<Object?> values) {
    var text = t(french);
    for (final (i, value) in values.indexed) {
      text = text.replaceAll('{$i}', '$value');
    }
    return text;
  }

  /// Singulier ou pluriel ({0} : le nombre). Zéro est au singulier en français, au pluriel en anglais.
  static String count(int n, String one, String many) => f(n > 1 || (n == 0 && isEnglish) ? many : one, [n]);
}
