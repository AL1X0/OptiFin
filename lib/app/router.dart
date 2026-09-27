import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../features/auth/presentation/connect_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/home/presentation/home_screen.dart';

abstract final class Routes {
  static const home = '/';
  static const connect = '/connect';
  static const login = '/connect/login';
}

final routerProvider = Provider<GoRouter>((ref) {
  // Pont Riverpod → Listenable pour que go_router réévalue les redirections.
  final sessionListenable = ValueNotifier(ref.read(sessionControllerProvider));
  ref.listen(sessionControllerProvider, (_, next) => sessionListenable.value = next);
  ref.onDispose(sessionListenable.dispose);

  final router = GoRouter(
    initialLocation: sessionListenable.value == null ? Routes.connect : Routes.home,
    refreshListenable: sessionListenable,
    redirect: (context, state) {
      final signedIn = sessionListenable.value != null;
      final inConnect = state.matchedLocation.startsWith(Routes.connect);
      if (!signedIn && !inConnect) return Routes.connect;
      return null; // connecté : /connect reste accessible pour « Ajouter un compte »
    },
    routes: [
      GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: Routes.connect,
        builder: (_, _) => const ConnectScreen(),
        routes: [
          GoRoute(path: 'login', builder: (_, state) => LoginScreen(initialUsername: state.extra as String?)),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
