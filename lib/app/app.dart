import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      builder: (context, child) => OFDevice.tv ? _TvFocusRescue(child: child!) : child!,
    );
  }
}

/// Télécommande : si rien n'a le focus (écran qui vient de s'ouvrir), la première flèche
/// le donne au premier élément de l'écran au lieu de ne rien faire.
class _TvFocusRescue extends StatelessWidget {
  const _TvFocusRescue({required this.child});

  final Widget child;

  static final _arrows = {
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
  };

  @override
  Widget build(BuildContext context) {
    TvScrollToTop.install();
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent || !_arrows.contains(event.logicalKey)) return KeyEventResult.ignored;
        final primary = FocusManager.instance.primaryFocus;
        if (primary != null && primary is! FocusScopeNode) return KeyEventResult.ignored;
        final scope = primary is FocusScopeNode ? primary : node.nearestScope;
        return (scope?.nextFocus() ?? false) ? KeyEventResult.handled : KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
