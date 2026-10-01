import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/features/syncplay/domain/syncplay_models.dart';
import 'package:optifin/features/syncplay/domain/syncplay_sync.dart';

// Messages relevés sur un serveur Jellyfin 12.1.
const _joined =
    '{"MessageType":"SyncPlayGroupUpdate","Data":{"GroupId":"8bfb","Data":{"GroupId":"8bfb","GroupName":"Soirée test","State":"Idle","Participants":["alice","bob"],"LastUpdatedAt":"2026-10-01T13:48:59.7626513Z"},"Type":"GroupJoined"}}';
const _queue =
    '{"MessageType":"SyncPlayGroupUpdate","Data":{"GroupId":"8bfb","Data":{"Reason":"NewPlaylist","LastUpdate":"2026-10-01T13:49:00.3458894Z","Playlist":[{"ItemId":"63fc","PlaylistItemId":"1453"}],"PlayingItemIndex":0,"StartPositionTicks":600000000,"IsPlaying":false},"Type":"PlayQueue"}}';
const _unpause =
    '{"MessageType":"SyncPlayCommand","Data":{"GroupId":"8bfb","PlaylistItemId":"1453","When":"2026-10-01T13:49:03.4843524Z","PositionTicks":5478753,"Command":"Unpause","EmittedAt":"2026-10-01T13:49:02.4844414Z"}}';

class _FakePlayer implements SyncTarget {
  @override
  Duration position = Duration.zero;
  @override
  bool paused = true;
  double rate = 1;
  int seeks = 0;

  @override
  void play() => paused = false;
  @override
  void pause() => paused = true;
  @override
  void seek(Duration p) {
    position = p;
    seeks++;
  }

  @override
  void setRate(double r) => rate = r;
}

class _FakeRequests implements SyncRequests {
  final sent = <String>[];
  @override
  Future<void> ready(
    Duration position, {
    required bool isPlaying,
    required String playlistItemId,
  }) async => sent.add('ready ${position.inSeconds} $isPlaying');
  @override
  Future<void> buffering(
    Duration position, {
    required bool isPlaying,
    required String playlistItemId,
  }) async => sent.add('buffering $isPlaying');
  @override
  Future<void> pause() async => sent.add('pause');
  @override
  Future<void> unpause() async => sent.add('unpause');
  @override
  Future<void> seek(Duration position) async =>
      sent.add('seek ${position.inSeconds}');
}

final _t0 = DateTime.utc(2026, 1, 1, 20);

({
  SyncPlayPlayback sync,
  _FakePlayer player,
  _FakeRequests requests,
  void Function(DateTime) setNow,
})
_make() {
  var now = _t0;
  final time = TimeSync(now: () => now);
  // Serveur en avance de 2 s sur l'horloge locale.
  final server = _t0.add(const Duration(seconds: 2));
  time.addSample(_t0, server, server, _t0);
  final player = _FakePlayer();
  final requests = _FakeRequests();
  return (
    sync: SyncPlayPlayback(player, requests, time, 'pl1'),
    player: player,
    requests: requests,
    setNow: (t) => now = t,
  );
}

SyncCommand _cmd(
  SyncCommandKind kind,
  DateTime serverWhen,
  int seconds, {
  String id = 'pl1',
}) => SyncCommand(
  kind: kind,
  playlistItemId: id,
  when: serverWhen,
  position: Duration(seconds: seconds),
);

void main() {
  group('messages', () {
    test('groupe rejoint', () {
      final m = parseSyncPlayMessage(_joined)! as GroupJoined;
      expect(m.group.name, 'Soirée test');
      expect(m.group.participants, ['alice', 'bob']);
      expect(m.group.state, GroupState.idle);
    });

    test('file de lecture', () {
      final q = (parseSyncPlayMessage(_queue)! as QueueChanged).queue;
      expect(q.current!.itemId, '63fc');
      expect(q.start, const Duration(minutes: 1));
      expect(q.isPlaying, isFalse);
    });

    test('ordre horodaté (7 décimales)', () {
      final c = (parseSyncPlayMessage(_unpause)! as CommandReceived).command;
      expect(c.kind, SyncCommandKind.unpause);
      expect(c.when.isUtc, isTrue);
      expect(c.when.second, 3);
      expect(c.position, const Duration(microseconds: 547875));
    });

    test('autres messages', () {
      expect(
        parseSyncPlayMessage('{"MessageType":"ForceKeepAlive","Data":60}'),
        isA<KeepAliveRequest>(),
      );
      expect(
        parseSyncPlayMessage(
          '{"MessageType":"SyncPlayGroupUpdate","Data":{"Data":"bob","Type":"UserLeft"}}',
        ),
        isA<UserLeft>(),
      );
      expect(
        parseSyncPlayMessage(
          '{"MessageType":"SyncPlayGroupUpdate","Data":{"Data":"","Type":"LibraryAccessDenied"}}',
        ),
        isA<SyncPlayError>(),
      );
      expect(
        parseSyncPlayMessage('{"MessageType":"Sessions","Data":[]}'),
        isNull,
      );
      expect(parseSyncPlayMessage('pas du json'), isNull);
    });
  });

  test('horloge du serveur : décalage et meilleur aller-retour', () {
    final local = DateTime.utc(2026, 1, 1, 12);
    final sync = TimeSync(now: () => local);
    final s = local.add(const Duration(seconds: 5));
    sync.addSample(
      local,
      s.add(const Duration(milliseconds: 20)),
      s.add(const Duration(milliseconds: 21)),
      local.add(const Duration(milliseconds: 41)),
    );
    expect(sync.offset.inMilliseconds, 5000);
    expect(sync.roundTrip.inMilliseconds, 40);
    sync.addSample(
      local,
      s.add(const Duration(milliseconds: 400)),
      s.add(const Duration(milliseconds: 401)),
      local.add(const Duration(milliseconds: 500)),
    );
    expect(sync.offset.inMilliseconds, 5000);
  });

  group('synchronisation du lecteur', () {
    test('reprend à l’heure du serveur', () {
      final f = _make();
      f.sync.apply(
        _cmd(SyncCommandKind.unpause, _t0.add(const Duration(seconds: 3)), 10),
      );
      expect(f.player.paused, isTrue);
      expect(f.player.position, const Duration(seconds: 10));
      f.setNow(_t0.add(const Duration(milliseconds: 900)));
      f.sync.tick();
      expect(f.player.paused, isTrue);
      f.setNow(_t0.add(const Duration(seconds: 1)));
      f.sync.tick();
      expect(f.player.paused, isFalse);
    });

    test('en retard, rejoint le groupe', () {
      final f = _make();
      f.setNow(_t0.add(const Duration(seconds: 5)));
      f.sync.apply(
        _cmd(SyncCommandKind.unpause, _t0.add(const Duration(seconds: 3)), 10),
      );
      expect(f.player.paused, isFalse);
      expect(f.player.position, const Duration(seconds: 14));
    });

    test('rattrape la dérive', () {
      final f = _make();
      f.sync.apply(
        _cmd(SyncCommandKind.unpause, _t0.add(const Duration(seconds: 2)), 0),
      );
      f.setNow(_t0.add(const Duration(seconds: 10)));
      f.player.position = const Duration(milliseconds: 10300);
      f.sync.tick();
      expect(f.player.rate, 0.95);
      f.player.position = const Duration(milliseconds: 10010);
      f.sync.tick();
      expect(f.player.rate, 1);
      f.player.position = const Duration(seconds: 8);
      f.sync.tick();
      expect(f.player.position, const Duration(seconds: 10));
    });

    test('pause, saut puis prêt', () {
      final f = _make();
      f.sync.apply(
        _cmd(SyncCommandKind.unpause, _t0.add(const Duration(seconds: 2)), 0),
      );
      f.sync.apply(
        _cmd(SyncCommandKind.pause, _t0.add(const Duration(seconds: 2)), 42),
      );
      expect(f.player.paused, isTrue);
      expect(f.player.position, const Duration(seconds: 42));
      f.sync.apply(
        _cmd(SyncCommandKind.seek, _t0.add(const Duration(seconds: 2)), 600),
      );
      expect(f.player.position, const Duration(seconds: 600));
      expect(f.sync.waiting, isTrue);
      f.sync.onSeekCompleted();
      expect(f.requests.sent.last, 'ready 600 false');
    });

    test('ignore un autre élément, transmet les actions, coupures courtes ignorées', () {
      final f = _make();
      f.sync.apply(
        _cmd(
          SyncCommandKind.unpause,
          _t0.add(const Duration(seconds: 2)),
          0,
          id: 'autre',
        ),
      );
      expect(f.player.paused, isTrue);
      f.sync.requestTogglePlay();
      f.sync.requestSeek(const Duration(seconds: 90));
      expect(f.requests.sent, ['unpause', 'seek 90']);
      f.sync.onBuffering(true);
      f.sync.tick();
      expect(f.requests.sent.where((s) => s.startsWith('buffering')), isEmpty);
      f.setNow(_t0.add(const Duration(seconds: 1)));
      f.sync.tick();
      f.sync.onBuffering(false);
      expect(f.requests.sent[f.requests.sent.length - 2], 'buffering false');
    });
  });
}
