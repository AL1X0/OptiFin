import 'dart:async';
import 'dart:io';

import 'package:optifin/core/l10n/l.dart';

/// Captures en français, sauf OPTIFIN_LANGUAGE=en (kit marketing anglais).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  L.isEnglish = Platform.environment['OPTIFIN_LANGUAGE'] == 'en';
  await testMain();
}
