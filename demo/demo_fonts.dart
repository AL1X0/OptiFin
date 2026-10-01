import 'dart:io';

import 'package:flutter/services.dart';

/// Charge les vraies polices dans le moteur de test (sinon tout s'affiche en « Ahem ») :
/// Roboto et les icônes Material (cache Flutter), Georgia et Bahnschrift (Windows) pour les logos.
Future<void> loadDemoFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? r'C:\Users\Administrateur\dev\flutter';
  final material = '$flutterRoot/bin/cache/artifacts/material_fonts';
  const windows = r'C:\Windows\Fonts';

  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      final file = File(f);
      if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  }

  final roboto = [
    for (final w in ['thin', 'light', 'regular', 'medium', 'bold', 'black']) '$material/roboto-$w.ttf',
  ];
  // Sur iOS, Flutter demande la police système (SF Pro) sous ces noms : Roboto la remplace ici.
  for (final name in [
    'Roboto',
    'FlutterTest',
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
    '.SF Pro Text',
    '.SF Pro Display',
    '.SF UI Text',
    '.SF UI Display',
  ]) {
    await family(name, roboto);
  }
  await family('MaterialIcons', ['$material/materialicons-regular.otf']);
  await family('Georgia', ['$windows/georgia.ttf', '$windows/georgiab.ttf']);
  await family('Bahnschrift', ['$windows/bahnschrift.ttf']);
}
