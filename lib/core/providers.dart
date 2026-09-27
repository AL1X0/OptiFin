import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_api/jellyfin_api.dart';

import '../features/auth/data/account_store.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/domain/entities.dart';
import 'media/media_repository.dart';
import 'network/dio_factory.dart';
import 'network/image_url.dart';
import 'network/jellyfin_auth.dart';
import 'storage/app_database.dart';
import 'storage/token_vault.dart';

/// Dépendances initialisées dans `bootstrap()` puis injectées par override.
final appDatabaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('override in bootstrap'));
final tokenVaultProvider = Provider<TokenVault>((ref) => throw UnimplementedError('override in bootstrap'));
final clientIdentityProvider = Provider<ClientIdentity>((ref) => throw UnimplementedError('override in bootstrap'));

/// Session restaurée au démarrage (lecture locale seulement, aucun réseau).
final initialSessionProvider = Provider<ActiveSession?>((ref) => null);

final accountStoreProvider = Provider<AccountStore>(
  (ref) => AccountStore(ref.watch(appDatabaseProvider), ref.watch(tokenVaultProvider)),
);

/// Client non lié à la session courante (sonde de serveur, login).
final jellyfinClientFactoryProvider = Provider<JellyfinClientFactory>((ref) {
  final identity = ref.watch(clientIdentityProvider);
  return (Uri baseUrl, {String? token}) =>
      JellyfinClient(createJellyfinDio(baseUrl: baseUrl, identity: identity, tokenProvider: () => token));
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(jellyfinClientFactoryProvider)),
);

/// Session active ; null = écran de connexion.
final sessionControllerProvider = NotifierProvider<SessionController, ActiveSession?>(SessionController.new);

class SessionController extends Notifier<ActiveSession?> {
  @override
  ActiveSession? build() => ref.read(initialSessionProvider);

  AccountStore get _store => ref.read(accountStoreProvider);

  Future<void> signIn(ActiveSession session) async {
    await _store.saveSession(session);
    state = session;
  }

  /// Bascule vers un compte enregistré. Retourne false si son token a disparu.
  Future<bool> switchTo(String accountId) async {
    final session = await _store.switchTo(accountId);
    if (session == null) return false;
    state = session;
    return true;
  }

  /// Déconnexion explicite : révoque le token et oublie le compte.
  Future<void> signOut() async {
    final current = state;
    if (current == null) return;
    state = null;
    await ref.read(authRepositoryProvider).logout(current);
    await _store.removeAccount(current.account.id);
  }

  /// Token refusé par le serveur (401) : on retourne à l'écran de connexion
  /// en gardant le compte listé pour une reconnexion rapide.
  Future<void> handleUnauthorized() async {
    if (state == null) return;
    state = null;
    await _store.clearActive();
  }
}

/// Dio authentifié pour la session courante (en-tête Authorization, journaux).
final jellyfinDioProvider = Provider<Dio>((ref) {
  final session = ref.watch(sessionControllerProvider);
  if (session == null) throw StateError('Aucune session active');
  final dio = createJellyfinDio(
    baseUrl: session.server.baseUrl,
    identity: ref.watch(clientIdentityProvider),
    tokenProvider: () => session.token,
    onUnauthorized: () => ref.read(sessionControllerProvider.notifier).handleUnauthorized(),
  );
  ref.onDispose(dio.close);
  return dio;
});

/// Client authentifié pour la session courante.
final jellyfinClientProvider = Provider<JellyfinClient>((ref) => JellyfinClient(ref.watch(jellyfinDioProvider)));

final imageUrlBuilderProvider = Provider<JellyfinImageUrlBuilder>((ref) {
  final session = ref.watch(sessionControllerProvider);
  if (session == null) throw StateError('Aucune session active');
  return JellyfinImageUrlBuilder(session.server.baseUrl);
});

final savedAccountsProvider = FutureProvider<List<StoredAccount>>((ref) {
  ref.watch(sessionControllerProvider); // se rafraîchit à chaque changement de session
  return ref.watch(accountStoreProvider).listAccounts();
});

final responseCacheProvider = Provider<ResponseCache>((ref) => ResponseCache(ref.watch(appDatabaseProvider)));

/// Accès aux contenus pour la session courante (recréé à chaque bascule de compte).
final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  final session = ref.watch(sessionControllerProvider);
  if (session == null) throw StateError('Aucune session active');
  return MediaRepository(ref.watch(jellyfinClientProvider), session.account.userId);
});
