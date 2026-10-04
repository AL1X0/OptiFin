import 'dart:convert';

/// État d'une soirée (groupe SyncPlay) côté serveur.
enum GroupState { idle, waiting, paused, playing }

GroupState _state(Object? s) => switch (s) {
  'Waiting' => GroupState.waiting,
  'Paused' => GroupState.paused,
  'Playing' => GroupState.playing,
  _ => GroupState.idle,
};

/// Soirée : identifiant, nom, état, participants (noms d'utilisateur).
class GroupInfo {
  const GroupInfo({required this.id, required this.name, required this.state, required this.participants});

  factory GroupInfo.fromJson(Map<String, dynamic> j) => GroupInfo(
    id: j['GroupId'] as String? ?? '',
    name: j['GroupName'] as String? ?? 'Soirée',
    state: _state(j['State']),
    participants: [
      for (final p in (j['Participants'] as List? ?? const []))
        if (p is String && p.isNotEmpty) p,
    ],
  );

  final String id;
  final String name;
  final GroupState state;
  final List<String> participants;

  GroupInfo copyWith({GroupState? state, List<String>? participants}) =>
      GroupInfo(id: id, name: name, state: state ?? this.state, participants: participants ?? this.participants);
}

enum SyncCommandKind { unpause, pause, stop, seek }

/// Ordre du serveur à appliquer à l'heure [when] (heure du serveur, UTC).
class SyncCommand {
  const SyncCommand({required this.kind, required this.playlistItemId, required this.when, required this.position});

  factory SyncCommand.fromJson(Map<String, dynamic> j) => SyncCommand(
    kind: switch (j['Command']) {
      'Unpause' => SyncCommandKind.unpause,
      'Pause' => SyncCommandKind.pause,
      'Seek' => SyncCommandKind.seek,
      _ => SyncCommandKind.stop,
    },
    playlistItemId: j['PlaylistItemId'] as String? ?? '',
    when: parseServerTime(j['When']),
    position: ticksToDuration(j['PositionTicks']),
  );

  final SyncCommandKind kind;
  final String playlistItemId;
  final DateTime when;
  final Duration position;
}

class QueueItem {
  const QueueItem(this.itemId, this.playlistItemId);
  final String itemId;
  final String playlistItemId;
}

/// File de lecture partagée : l'élément en cours et sa position de départ.
class PlayQueue {
  const PlayQueue({
    required this.reason,
    required this.items,
    required this.playingIndex,
    required this.start,
    required this.isPlaying,
  });

  factory PlayQueue.fromJson(Map<String, dynamic> j) => PlayQueue(
    reason: j['Reason'] as String? ?? '',
    items: [
      for (final i in (j['Playlist'] as List? ?? const []))
        if (i is Map<String, dynamic>) QueueItem(i['ItemId'] as String? ?? '', i['PlaylistItemId'] as String? ?? ''),
    ],
    playingIndex: (j['PlayingItemIndex'] as num?)?.toInt() ?? -1,
    start: ticksToDuration(j['StartPositionTicks']),
    isPlaying: j['IsPlaying'] == true,
  );

  final String reason;
  final List<QueueItem> items;
  final int playingIndex;
  final Duration start;
  final bool isPlaying;

  QueueItem? get current => playingIndex >= 0 && playingIndex < items.length ? items[playingIndex] : null;
}

/// Message reçu par la connexion temps réel du serveur (/socket).
sealed class SyncPlayMessage {
  const SyncPlayMessage();
}

class GroupJoined extends SyncPlayMessage {
  const GroupJoined(this.group);
  final GroupInfo group;
}

class GroupLeft extends SyncPlayMessage {
  const GroupLeft();
}

class UserJoined extends SyncPlayMessage {
  const UserJoined(this.userName);
  final String userName;
}

class UserLeft extends SyncPlayMessage {
  const UserLeft(this.userName);
  final String userName;
}

class StateChanged extends SyncPlayMessage {
  const StateChanged(this.state, this.reason);
  final GroupState state;
  final String reason;
}

class QueueChanged extends SyncPlayMessage {
  const QueueChanged(this.queue);
  final PlayQueue queue;
}

class CommandReceived extends SyncPlayMessage {
  const CommandReceived(this.command);
  final SyncCommand command;
}

class SyncPlayError extends SyncPlayMessage {
  const SyncPlayError(this.kind, this.userMessage);
  final String kind;
  final String userMessage;
}

class KeepAliveRequest extends SyncPlayMessage {
  const KeepAliveRequest(this.seconds);
  final int seconds;
}

/// Lecture des messages de la connexion temps réel (SyncPlay et maintien de la connexion).
SyncPlayMessage? parseSyncPlayMessage(String raw) {
  try {
    final root = jsonDecode(raw);
    if (root is! Map<String, dynamic>) return null;
    final data = root['Data'];
    return switch (root['MessageType']) {
      'ForceKeepAlive' => KeepAliveRequest(data is num ? data.toInt() : 60),
      'SyncPlayCommand' when data is Map<String, dynamic> => CommandReceived(SyncCommand.fromJson(data)),
      'SyncPlayGroupUpdate' when data is Map<String, dynamic> => _groupUpdate(data),
      _ => null,
    };
  } on FormatException {
    return null;
  }
}

SyncPlayMessage? _groupUpdate(Map<String, dynamic> update) {
  final data = update['Data'];
  final type = '${update['Type']}';
  return switch (type) {
    'GroupJoined' when data is Map<String, dynamic> => GroupJoined(GroupInfo.fromJson(data)),
    'GroupLeft' => const GroupLeft(),
    'UserJoined' => UserJoined('${data ?? ''}'),
    'UserLeft' => UserLeft('${data ?? ''}'),
    'StateUpdate' when data is Map<String, dynamic> => StateChanged(
      _state(data['State']),
      data['Reason'] as String? ?? '',
    ),
    'PlayQueue' when data is Map<String, dynamic> => QueueChanged(PlayQueue.fromJson(data)),
    'NotInGroup' => SyncPlayError(type, 'Vous ne faites plus partie de cette soirée.'),
    'GroupDoesNotExist' => SyncPlayError(type, 'Cette soirée n’existe plus.'),
    'CreateGroupDenied' => SyncPlayError(
      type,
      'Votre compte n’a pas le droit de créer une soirée (réglage SyncPlay du serveur).',
    ),
    'JoinGroupDenied' => SyncPlayError(
      type,
      'Votre compte n’a pas le droit de rejoindre une soirée (réglage SyncPlay du serveur).',
    ),
    'LibraryAccessDenied' => SyncPlayError(type, 'Un participant n’a pas accès à ce titre dans ses bibliothèques.'),
    _ => null,
  };
}

Duration ticksToDuration(Object? ticks) => Duration(microseconds: ((ticks as num?) ?? 0) ~/ 10);

int durationToTicks(Duration d) => d.inMicroseconds * 10;

/// Heure du serveur (ISO 8601, 7 décimales) en UTC.
DateTime parseServerTime(Object? value) {
  if (value is! String) return DateTime.now().toUtc();
  // Dart n'accepte que 6 décimales : on tronque les secondes fractionnaires.
  final trimmed = value.replaceFirstMapped(RegExp(r'(\.\d{6})\d+'), (m) => m[1]!);
  return (DateTime.tryParse(trimmed) ?? DateTime.now()).toUtc();
}
