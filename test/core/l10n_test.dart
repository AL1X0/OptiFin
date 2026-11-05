import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/core/l10n/english_texts.dart';
import 'package:optifin/core/l10n/l.dart';

/// Traduction anglaise : aucune phrase du code oubliée, variables identiques des deux côtés.
void main() {
  test('toute phrase du code est traduite', () {
    final call = RegExp(r"""L\.(?:t|f)\('((?:[^'\\]|\\.)*)'|L\.count\([^,']+,\s*'((?:[^'\\]|\\.)*)',\s*'((?:[^'\\]|\\.)*)'\)""");
    final missing = <String>{};
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') || file.path.endsWith('l.dart')) continue;
      for (final m in call.allMatches(file.readAsStringSync())) {
        for (var i = 1; i <= 3; i++) {
          final key = m.group(i);
          if (key != null && !englishTexts.containsKey(key)) missing.add('${file.path} : $key');
        }
      }
    }
    expect(missing, isEmpty);
  });

  test('mêmes variables dans les deux langues', () {
    final placeholder = RegExp(r'\{\d+\}');
    List<String> of(String s) => [for (final m in placeholder.allMatches(s)) m[0]!]..sort();
    englishTexts.forEach((french, english) => expect(of(english), of(french), reason: french));
  });

  test('phrases en anglais et pluriels', () {
    addTearDown(() => L.isEnglish = false);
    L.isEnglish = false;
    expect(L.t('Lecture'), 'Lecture');
    expect(L.count(0, '{0} élément', '{0} éléments'), '0 élément');
    L.isEnglish = true;
    expect(L.t('Lecture'), 'Play');
    expect(L.count(1, '{0} élément', '{0} éléments'), '1 item');
    expect(L.count(0, '{0} élément', '{0} éléments'), '0 items');
    expect(L.f('Aucun résultat pour « {0} ».', ['x']), 'No results for “x”.');
  });
}
