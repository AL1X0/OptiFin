import 'dart:async';

import 'package:optifin/core/l10n/l.dart';

/// Textes français attendus par les tests, quelle que soit la langue du poste.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  L.isEnglish = false;
  await testMain();
}
