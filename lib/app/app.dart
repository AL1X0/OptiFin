import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design_system/design_system.dart';
import 'router.dart';

class OptiFinApp extends ConsumerWidget {
  const OptiFinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'OptiFin',
      debugShowCheckedModeBanner: false,
      theme: OFTheme.dark(),
      darkTheme: OFTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
