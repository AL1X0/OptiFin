import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../features/auth/presentation/connect_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/details/presentation/item_details_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/library/presentation/libraries_screen.dart';
import '../features/library/presentation/library_providers.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/person/presentation/person_screen.dart';
import '../features/player/presentation/player_controller.dart';
import '../features/player/presentation/player_screen.dart';
import '../features/downloads/presentation/downloads_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/settings/presentation/logs_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'app_shell.dart';

abstract final class Routes {
  static const home = '/home';
  static const libraries = '/libraries';
  static const search = '/search';
  static const downloads = '/downloads';
  static const connect = '/connect';
  static const login = '/connect/login';
  static const settings = '/settings';
  static const logs = '/settings/logs';

  /// Lecteur plein écran ; `start` en millisecondes (absent = reprise serveur).
  static String play(String itemId, {Duration? start}) => Uri(
    path: '/play/$itemId',
    queryParameters: start == null ? null : {'start': '${start.inMilliseconds}'},
  ).toString();
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Routes de contenu disponibles sous chaque onglet (la fiche s'ouvre dans
/// l'onglet courant : barre d'onglets conservée, retour naturel).
List<RouteBase> _contentRoutes() => [
  GoRoute(
    path: 'item/:id',
    builder: (_, s) => ItemDetailsScreen(
      itemId: s.pathParameters['id']!,
      heroTag: s.extra is String ? s.extra! as String : null,
      initialSeasonId: s.uri.queryParameters['season'],
    ),
  ),
  GoRoute(
    path: 'person/:id',
    builder: (_, s) => PersonScreen(personId: s.pathParameters['id']!),
  ),
  GoRoute(
    path: 'library/:id',
    builder: (_, s) => LibraryScreen(source: ViewSource(s.pathParameters['id']!)),
  ),
  GoRoute(
    path: 'genre/:id',
    builder: (_, s) =>
        LibraryScreen(source: GenreSource(s.pathParameters['id']!, s.uri.queryParameters['name'] ?? 'Genre')),
  ),
  GoRoute(
    path: 'studio/:id',
    builder: (_, s) =>
        LibraryScreen(source: StudioSource(s.pathParameters['id']!, s.uri.queryParameters['name'] ?? 'Studio')),
  ),
];

final routerProvider = Provider<GoRouter>((ref) {
  // Pont Riverpod → Listenable pour que go_router réévalue les redirections.
  final sessionListenable = ValueNotifier(ref.read(sessionControllerProvider));
  ref.listen(sessionControllerProvider, (_, next) => sessionListenable.value = next);
  ref.onDispose(sessionListenable.dispose);

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: sessionListenable.value == null ? Routes.connect : Routes.home,
    refreshListenable: sessionListenable,
    redirect: (context, state) {
      final signedIn = sessionListenable.value != null;
      final inConnect = state.matchedLocation.startsWith(Routes.connect);
      if (!signedIn && !inConnect) return Routes.connect;
      if (signedIn && state.matchedLocation == '/') return Routes.home;
      return null; // connecté : /connect reste accessible pour « Ajouter un compte »
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => Routes.home),
      StatefulShellRoute(
        builder: (_, _, shell) => AppShell(shell: shell),
        // Changement d'onglet : fondu enchaîné (les onglets restent vivants comme avec indexedStack).
        navigatorContainerBuilder: (_, shell, children) =>
            FadingBranches(index: shell.currentIndex, children: children),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen(), routes: _contentRoutes())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.libraries, builder: (_, _) => const LibrariesScreen(), routes: _contentRoutes()),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.search, builder: (_, _) => const SearchScreen(), routes: _contentRoutes())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.downloads, builder: (_, _) => const DownloadsScreen(), routes: _contentRoutes()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/play/:id',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) {
          final startMs = int.tryParse(s.uri.queryParameters['start'] ?? '');
          return CustomTransitionPage<void>(
            key: s.pageKey,
            opaque: true,
            barrierColor: const Color(0xFF000000),
            transitionDuration: const Duration(milliseconds: 180),
            reverseTransitionDuration: const Duration(milliseconds: 200),
            transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
            child: PlayerScreen(
              args: PlayerArgs(
                s.pathParameters['id']!,
                start: startMs == null ? null : Duration(milliseconds: startMs),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: Routes.settings,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SettingsScreen(),
        routes: [GoRoute(path: 'logs', builder: (_, _) => const LogsScreen())],
      ),
      GoRoute(
        path: Routes.connect,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const ConnectScreen(),
        routes: [
          GoRoute(
            path: 'login',
            builder: (_, state) => LoginScreen(initialUsername: state.extra as String?),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
