import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/server_discovery.dart';
import '../domain/entities.dart';

final serverDiscoveryProvider = Provider<ServerDiscovery>((ref) => ServerDiscovery());

/// Serveurs du réseau local ; relancé à chaque `ref.invalidate`.
final discoveredServersProvider = StreamProvider.autoDispose<List<DiscoveredServer>>(
  (ref) => ref.watch(serverDiscoveryProvider).discover(),
);

/// Serveur validé en cours de connexion (entre l'écran serveur et l'écran login).
final pendingServerProvider = NotifierProvider<PendingServer, JellyfinServer?>(PendingServer.new);

class PendingServer extends Notifier<JellyfinServer?> {
  @override
  JellyfinServer? build() => null;

  void set(JellyfinServer? server) => state = server;
}

final publicUsersProvider = FutureProvider.autoDispose.family<List<PublicUser>, JellyfinServer>(
  (ref, server) => ref.watch(authRepositoryProvider).publicUsers(server),
);

final quickConnectEnabledProvider = FutureProvider.autoDispose.family<bool, JellyfinServer>(
  (ref, server) => ref.watch(authRepositoryProvider).isQuickConnectEnabled(server),
);
