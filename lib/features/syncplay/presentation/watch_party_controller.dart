import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/logging/app_log.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/jellyfin_auth.dart';
import '../../../core/providers.dart';
import '../data/syncplay_client.dart';
import '../domain/syncplay_models.dart';

/// Messages éphémères (arrivée d'un participant, erreur de soirée), affichés partout dans l'appli.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>(
  debugLabel: 'messages',
);

/// Ouverture du lecteur pour une soirée : élément de la file, position et état de départ.
class PartyStart {
  const PartyStart({
    required this.itemId,
    required this.playlistItemId,
    required this.start,
    required this.isPlaying,
  });
  final String itemId;
  final String playlistItemId;
  final Duration start;
  final bool isPlaying;
}

class WatchPartyState {
  const WatchPartyState({
    this.group,
    this.connected = false,
    this.available = false,
  });

  /// Soirée rejointe (null hors soirée).
  final GroupInfo? group;
  final bool connected;

  /// Un compte est connecté (la soirée est possible).
  final bool available;

  bool get inParty => group != null;
}

/// Soirées (SyncPlay de Jellyfin) à l'échelle de l'appli : connexion ouverte dès qu'un compte est
/// actif, état du groupe pour l'interface, et ouverture du lecteur chez tout le monde quand un
/// participant lance un titre.
final watchPartyProvider =
    NotifierProvider<WatchPartyController, WatchPartyState>(
      WatchPartyController.new,
    );

class WatchPartyController extends Notifier<WatchPartyState> {
  /// Connexion temps réel au serveur ; désactivée dans les tests d'écrans (pas de serveur).
  static bool autoConnect = true;

  SyncPlayClient? _client;
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _commands = StreamController<SyncCommand>.broadcast();
  final _states = StreamController<GroupState>.broadcast();
  String? _openedPlaylistItem;

  /// Dernière file reçue : le lecteur s'en sert pour se synchroniser.
  PartyStart? pending;

  SyncPlayClient? get client => _client;
  Stream<SyncCommand> get commands => _commands.stream;
  Stream<GroupState> get groupStates => _states.stream;

  @override
  WatchPartyState build() {
    final session = ref.watch(sessionControllerProvider);
    ref.onDispose(_release);
    if (session == null) return const WatchPartyState();
    if (!autoConnect) return const WatchPartyState(available: true);
    final identity = ref.read(clientIdentityProvider);
    final client = SyncPlayClient(
      dio: ref.watch(jellyfinDioProvider),
      baseUrl: session.server.baseUrl,
      authorization: () =>
          buildAuthorizationHeader(identity, token: session.token),
    );
    _client = client;
    _subscriptions
      ..add(client.messages.listen(_onMessage))
      ..add(
        client.connectionChanges.listen(
          (c) => state = WatchPartyState(
            group: client.group,
            connected: c,
            available: true,
          ),
        ),
      );
    client.start();
    return const WatchPartyState(available: true);
  }

  void _release() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _subscriptions.clear();
    unawaited(_client?.dispose());
    _client = null;
    _openedPlaylistItem = null;
    pending = null;
  }

  void _onMessage(SyncPlayMessage message) {
    final client = _client;
    if (client == null) return;
    switch (message) {
      case GroupJoined(:final group):
        _notice('Vous avez rejoint « ${group.name} »');
      case GroupLeft():
        _openedPlaylistItem = null;
        pending = null;
        _notice('Vous avez quitté la soirée');
      case UserJoined(:final userName):
        _notice('$userName a rejoint la soirée');
      case UserLeft(:final userName):
        _notice('$userName a quitté la soirée');
      case SyncPlayError(:final userMessage):
        _notice(userMessage);
      case StateChanged(state: final s):
        _states.add(s);
      case CommandReceived(:final command):
        if (command.kind == SyncCommandKind.stop) _openedPlaylistItem = null;
        _commands.add(command);
      case QueueChanged(:final queue):
        _onQueue(queue);
      case KeepAliveRequest():
        break;
    }
    state = WatchPartyState(
      group: client.group,
      connected: client.connected,
      available: true,
    );
  }

  void _onQueue(PlayQueue queue) {
    final current = queue.current;
    if (current == null || current.playlistItemId == _openedPlaylistItem) {
      return;
    }
    if (!const {
      'NewPlaylist',
      'SetCurrentItem',
      'NextItem',
      'PreviousItem',
    }.contains(queue.reason)) {
      return;
    }
    _openedPlaylistItem = current.playlistItemId;
    pending = PartyStart(
      itemId: current.itemId,
      playlistItemId: current.playlistItemId,
      start: queue.start,
      isPlaying: queue.isPlaying,
    );
    final router = ref.read(routerProvider);
    final location = Routes.play(current.itemId, start: queue.start);
    final inPlayer = router.routerDelegate.currentConfiguration.uri.path
        .startsWith('/play/');
    AppLog.i('syncplay', 'Titre lancé par la soirée : ${current.itemId}');
    unawaited(
      inPlayer
          ? router.pushReplacement<void>(location)
          : router.push<void>(location),
    );
  }

  /// Synchronisation à utiliser par le lecteur qui ouvre [itemId] (null hors soirée).
  PartyStart? partyFor(String itemId) =>
      state.inParty && pending?.itemId == itemId ? pending : null;

  void _notice(String text) {
    rootMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.groups_rounded, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(text)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ------------------------------------------------------------ Actions

  Future<List<GroupInfo>> list() async => await _client?.list() ?? const [];

  Future<void> create(String name) => _safe(() => _client!.create(name));
  Future<void> join(String groupId) => _safe(() => _client!.join(groupId));

  Future<void> leave() async {
    await _safe(() => _client!.leave());
    _openedPlaylistItem = null;
    pending = null;
    final client = _client;
    if (client != null) {
      state = WatchPartyState(
        group: client.group,
        connected: client.connected,
        available: true,
      );
    }
  }

  /// Lance un titre pour toute la soirée (chacun l'ouvre à cette position).
  Future<void> play(String itemId, {Duration start = Duration.zero}) {
    AppLog.i('syncplay', 'Lancement pour la soirée : $itemId');
    return _safe(() => _client!.setQueue([itemId], start: start));
  }

  Future<void> _safe(Future<void> Function() action) async {
    if (_client == null) return;
    try {
      await action();
    } catch (e) {
      AppLog.w('syncplay', '$e');
      _notice(
        e is ApiFailure
            ? e.userMessage
            : 'La soirée n’a pas pu être mise à jour.',
      );
    }
  }
}
