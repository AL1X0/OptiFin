import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design_system/design_system.dart';
import '../features/syncplay/presentation/watch_party_controller.dart';
import 'router.dart';

class OptiFinApp extends ConsumerWidget {
  const OptiFinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Soirées : connexion temps réel ouverte dès qu'un compte est actif (sans reconstruire l'appli).
    ref.listen(watchPartyProvider, (_, _) {});
    return MaterialApp.router(
      title: 'OptiFin',
      scaffoldMessengerKey: rootMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: OFTheme.dark(),
      darkTheme: OFTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
