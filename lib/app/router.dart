import 'package:flutter/material.dart';
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
import 'route_titles.dart';

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

/// Route à page Material explicite. go_router 18 cherche le `MaterialApp` de material_ui ;
/// l'app utilise celui de flutter/material, donc avec `builder:` il retombe sur des pages
/// sans transition — ni glissement, ni retour par glissé depuis le bord sur iOS.
GoRoute appRoute(
  String path,
  Widget Function(GoRouterState state) build, {
  GlobalKey<NavigatorState>? parentNavigatorKey,
  List<RouteBase> routes = const [],
}) => GoRoute(
  path: path,
  parentNavigatorKey: parentNavigatorKey,
  pageBuilder: (_, s) =>
      MaterialPage<void>(key: s.pageKey, name: s.uri.toString(), restorationId: s.pageKey.value, child: build(s)),
  routes: routes,
);

/// Routes de contenu disponibles sous chaque onglet (la fiche s'ouvre dans
/// l'onglet courant : barre d'onglets conservée, retour naturel).
List<RouteBase> _contentRoutes() => [
  appRoute(
    'item/:id',
    (s) => ItemDetailsScreen(
      itemId: s.pathParameters['id']!,
      heroTag: s.extra is String ? s.extra! as String : null,
      initialSeasonId: s.uri.queryParameters['season'],
    ),
  ),
  appRoute('person/:id', (s) => PersonScreen(personId: s.pathParameters['id']!)),
  appRoute('library/:id', (s) => LibraryScreen(source: ViewSource(s.pathParameters['id']!))),
  appRoute(
    'genre/:id',
    (s) => LibraryScreen(source: GenreSource(s.pathParameters['id']!, s.uri.queryParameters['name'] ?? 'Genre')),
  ),
  appRoute(
    'studio/:id',
    (s) => LibraryScreen(source: StudioSource(s.pathParameters['id']!, s.uri.queryParameters['name'] ?? 'Studio')),
  ),
];

final routerProvider = Provider<GoRouter>((ref) {
  // Pont Riverpod → Listenable pour que go_router réévalue les redirections.
  final sessionListenable = ValueNotifier(ref.read(sessionControllerProvider));
  ref.listen(sessionControllerProvider, (_, next) => sessionListenable.value = next);
  ref.onDispose(sessionListenable.dispose);

  final router = GoRouter(
    navigatorKey: _rootKey,
    observers: [OFNavObserver()],
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
            routes: [
              appRoute(
                Routes.home,
                (_) => const OFRouteTitle(title: 'Accueil', child: HomeScreen()),
                routes: _contentRoutes(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              appRoute(
                Routes.libraries,
                (_) => const OFRouteTitle(title: 'Bibliothèques', child: LibrariesScreen()),
                routes: _contentRoutes(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              appRoute(
                Routes.search,
                (_) => const OFRouteTitle(title: 'Recherche', child: SearchScreen()),
                routes: _contentRoutes(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              appRoute(
                Routes.downloads,
                (_) => const OFRouteTitle(title: 'Téléchargements', child: DownloadsScreen()),
                routes: _contentRoutes(),
              ),
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
      appRoute(
        Routes.settings,
        parentNavigatorKey: _rootKey,
        (_) => const SettingsScreen(),
        routes: [appRoute('logs', (_) => const LogsScreen())],
      ),
      appRoute(
        Routes.connect,
        parentNavigatorKey: _rootKey,
        (_) => const ConnectScreen(),
        routes: [appRoute('login', (state) => LoginScreen(initialUsername: state.extra as String?))],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
