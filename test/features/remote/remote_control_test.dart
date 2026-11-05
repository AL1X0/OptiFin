import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/features/remote/remote_control.dart';
import 'package:optifin/features/syncplay/domain/syncplay_models.dart';

void main() {
  group('appareils pilotables', () {
    test('ni soi-même, ni ceux qui ne lisent pas de vidéo ou ne se laissent pas piloter', () {
      final devices = parseRemoteDevices([
        {'Id': 'moi', 'DeviceId': 'd1', 'DeviceName': 'Téléphone', 'SupportsRemoteControl': true},
        {'Id': 'off', 'DeviceId': 'd2', 'DeviceName': 'Fermé', 'SupportsRemoteControl': false},
        {
          'Id': 'audio',
          'DeviceId': 'd3',
          'DeviceName': 'Enceinte',
          'SupportsRemoteControl': true,
          'PlayableMediaTypes': ['Audio'],
        },
        {
          'Id': 'tv',
          'DeviceId': 'd4',
          'DeviceName': 'Salon',
          'Client': 'OptiFin',
          'SupportsRemoteControl': true,
          'PlayableMediaTypes': ['Video'],
          'NowPlayingItem': {'Name': 'Horizon', 'RunTimeTicks': 72000000000},
          'PlayState': {'PositionTicks': 18000000000, 'IsPaused': true},
        },
      ], 'd1');
      final tv = devices.single;
      expect(tv.sessionId, 'tv');
      expect(tv.name, 'Salon');
      expect(tv.nowPlaying, 'Horizon');
      expect(tv.position, const Duration(minutes: 30));
      expect(tv.runtime, const Duration(hours: 2));
      expect(tv.paused, isTrue);
    });
  });

  group('messages reçus', () {
    test('demande de lecture', () {
      final m = parseSyncPlayMessage(
        '{"MessageType":"Play","Data":{"ItemIds":["abc"],"StartPositionTicks":1800000000,"PlayCommand":"PlayNow"}}',
      );
      expect(m, isA<RemotePlay>().having((p) => p.itemId, 'id', 'abc').having((p) => p.start, 'départ', const Duration(minutes: 3)));
    });

    test('seule la lecture immédiate est acceptée', () {
      expect(parseSyncPlayMessage('{"MessageType":"Play","Data":{"ItemIds":["abc"],"PlayCommand":"PlayLast"}}'), isNull);
    });

    test('commandes', () {
      expect(
        parseSyncPlayMessage('{"MessageType":"Playstate","Data":{"Command":"Seek","SeekPositionTicks":3000000000}}'),
        isA<RemoteCommand>().having((c) => c.command, 'commande', 'Seek').having((c) => c.seek, 'saut', const Duration(minutes: 5)),
      );
      expect(
        parseSyncPlayMessage('{"MessageType":"Playstate","Data":{"Command":"Pause"}}'),
        isA<RemoteCommand>().having((c) => c.seek, 'saut', isNull),
      );
    });
  });
}
