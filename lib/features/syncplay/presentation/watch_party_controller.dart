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
import '../../../core/l10n/l.dart';

/// Messages éphémères (arrivée d'un participant, erreur de soirée), affichés partout dans l'appli.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>(debugLabel: 'messages');

/// Ouverture du lecteur pour une soirée : élément de la file, position et état de départ.
class PartyStart {
  const PartyStart({required this.itemId, required this.playlistItemId, required this.start, required this.isPlaying});
  final String itemId;
  final String playlistItemId;
  final Duration start;
  final bool isPlaying;
}

class WatchPartyState {
  const WatchPartyState({this.group, this.connected = false, this.available = false});

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
final watchPartyProvider = NotifierProvider<WatchPartyController, WatchPartyState>(WatchPartyController.new);

class WatchPartyController extends Notifier<WatchPartyState> {
  /// Connexion temps réel au serveur ; désactivée dans les tests d'écrans (pas de serveur).
  static bool autoConnect = true;

  SyncPlayClient? _client;
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _commands = StreamController<SyncCommand>.broadcast();
  final _states = StreamController<GroupState>.broadcast();
  final _remoteCommands = StreamController<RemoteCommand>.broadcast();
  String? _openedPlaylistItem;
  final _replacedPlaylistItems = <String>{};
  bool _creating = false, _created = false, _launching = false;
  bool _launched = false, _stopping = false;

  /// Hôte de la soirée : celui qui l'a créée ou qui a lancé le titre en cours. Quand il quitte le
  /// lecteur, la lecture s'arrête pour tout le monde.
  bool get isHost => state.inParty && (_created || _launched);

  /// Dernière file reçue : le lecteur s'en sert pour se synchroniser.
  PartyStart? pending;

  SyncPlayClient? get client => _client;
  Stream<SyncCommand> get commands => _commands.stream;
  Stream<GroupState> get groupStates => _states.stream;
  Stream<RemoteCommand> get remoteCommands => _remoteCommands.stream;

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
      authorization: () => buildAuthorizationHeader(identity, token: session.token),
    );
    _client = client;
    _subscriptions
      ..add(client.messages.listen(_onMessage))
      ..add(
        client.connectionChanges.listen(
          (c) => state = WatchPartyState(group: client.group, connected: c, available: true),
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
    _replacedPlaylistItems.clear();
    pending = null;
    _resetHost();
  }

  void _resetHost() => _creating = _created = _launching = _launched = false;

  void _onMessage(SyncPlayMessage message) {
    final client = _client;
    if (client == null) return;
    switch (message) {
      case GroupJoined(:final group):
        _created = _creating;
        _creating = false;
        _notice(L.f('Vous avez rejoint « {0} »', [group.name]));
      case GroupLeft():
        _openedPlaylistItem = null;
        _replacedPlaylistItems.clear();
        pending = null;
        _resetHost();
        _notice('Vous avez quitté la soirée');
      case UserJoined(:final userName):
        _notice(L.f('{0} a rejoint la soirée', [userName]));
      case UserLeft(:final userName):
        _notice(L.f('{0} a quitté la soirée', [userName]));
      case SyncPlayError(:final userMessage):
        _notice(userMessage);
      case StateChanged(state: final s):
        _states.add(s);
      case CommandReceived(:final command):
        if (command.kind == SyncCommandKind.stop) {
          _openedPlaylistItem = null;
          final id = command.playlistItemId;
          if (!_stopping && id.replaceAll('0', '').isNotEmpty && pending != null) {
            _notice('L’hôte a arrêté la lecture');
          }
          _stopping = false;
        }
        _commands.add(command);
      case QueueChanged(:final queue):
        _onQueue(queue);
      case KeepAliveRequest():
        break;
      case RemotePlay(:final itemId, :final start):
        _onRemotePlay(itemId, start);
      case RemoteCommand():
        if (!state.inParty) _remoteCommands.add(message);
    }
    state = WatchPartyState(group: client.group, connected: client.connected, available: true);
  }

  /// « Lire sur… » depuis un autre appareil : le lecteur s'ouvre ici (jamais pendant une soirée).
  void _onRemotePlay(String itemId, Duration start) {
    if (state.inParty) return;
    final router = ref.read(routerProvider);
    final location = Routes.play(itemId, start: start);
    final inPlayer = router.routerDelegate.currentConfiguration.uri.path.startsWith('/play/');
    AppLog.i('remote', 'Lecture demandée par un autre appareil : $itemId');
    unawaited(inPlayer ? router.pushReplacement<void>(location) : router.push<void>(location));
  }

  void _onQueue(PlayQueue queue) {
    // Nouveau titre : lancé par nous (hôte de ce titre) ou par un autre participant.
    if (queue.reason == 'NewPlaylist') {
      _launched = _launching;
      _launching = false;
    }
    final current = queue.current;
    if (current == null || current.playlistItemId == _openedPlaylistItem) {
      return;
    }
    if (!const {'NewPlaylist', 'SetCurrentItem', 'NextItem', 'PreviousItem'}.contains(queue.reason)) {
      return;
    }
    final previous = _openedPlaylistItem;
    _openedPlaylistItem = current.playlistItemId;
    pending = PartyStart(
      itemId: current.itemId,
      playlistItemId: current.playlistItemId,
      start: queue.start,
      isPlaying: queue.isPlaying,
    );
    final router = ref.read(routerProvider);
    final location = Routes.play(current.itemId, start: queue.start);
    final inPlayer = router.routerDelegate.currentConfiguration.uri.path.startsWith('/play/');
    if (inPlayer && previous != null) {
      _replacedPlaylistItems.add(previous);
    }
    AppLog.i('syncplay', 'Titre lancé par la soirée : ${current.itemId}');
    unawaited(inPlayer ? router.pushReplacement<void>(location) : router.push<void>(location));
  }

  /// Vrai si le lecteur de [playlistItemId] vient d'être remplacé par un autre titre
  /// de la soirée (sa fermeture ne doit pas arrêter la lecture pour tout le monde).
  bool consumeReplaced(String playlistItemId) => _replacedPlaylistItems.remove(playlistItemId);

  /// Synchronisation à utiliser par le lecteur qui ouvre [itemId] (null hors soirée).
  PartyStart? partyFor(String itemId) => state.inParty && pending?.itemId == itemId ? pending : null;

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

  Future<void> create(String name) {
    _creating = true;
    return _safe(() => _client!.create(name));
  }

  Future<void> join(String groupId) => _safe(() => _client!.join(groupId));

  Future<void> leave() async {
    await _safe(() => _client!.leave());
    _openedPlaylistItem = null;
    _replacedPlaylistItems.clear();
    pending = null;
    _resetHost();
    final client = _client;
    if (client != null) {
      state = WatchPartyState(group: client.group, connected: client.connected, available: true);
    }
  }

  /// Lance un titre pour toute la soirée (chacun l'ouvre à cette position).
  Future<void> play(String itemId, {Duration start = Duration.zero}) {
    AppLog.i('syncplay', 'Lancement pour la soirée : $itemId');
    _launching = true;
    return _safe(() => _client!.setQueue([itemId], start: start));
  }

  /// L'hôte quitte le lecteur : arrêt de la lecture pour toute la soirée.
  Future<void> stopForAll() async {
    if (!isHost) return;
    AppLog.i('syncplay', 'L’hôte quitte la lecture : arrêt pour la soirée');
    _stopping = true;
    await _safe(() => _client!.stop());
  }

  Future<void> _safe(Future<void> Function() action) async {
    if (_client == null) return;
    try {
      await action();
    } catch (e) {
      AppLog.w('syncplay', '$e');
      _notice(e is ApiFailure ? e.userMessage : L.t('La soirée n’a pas pu être mise à jour.'));
    }
  }
}
