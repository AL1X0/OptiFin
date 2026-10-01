import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/core/network/jellyfin_auth.dart';
import 'package:optifin/features/syncplay/data/syncplay_client.dart';
import 'package:optifin/features/syncplay/domain/syncplay_models.dart';

/// Bout en bout contre un vrai serveur Jellyfin (facultatif) : variable d'environnement
/// OPTIFIN_TEST_SERVER = fichier JSON {"url", "users":[{"name","password"},…]} (deux comptes).
void main() {
  final file = Platform.environment['OPTIFIN_TEST_SERVER'];
  final available = file != null && File(file).existsSync();

  Future<(SyncPlayClient, String)> signIn(
    Uri base,
    Map<String, dynamic> user,
    String device,
  ) async {
    final identity = ClientIdentity(
      clientName: 'OptiFinTests',
      deviceName: device,
      deviceId: 'dart-$device',
      version: '1',
    );
    final login = await Dio().post<Map<String, dynamic>>(
      '$base/Users/AuthenticateByName',
      data: {'Username': user['name'], 'Pw': user['password']},
      options: Options(
        headers: {'Authorization': buildAuthorizationHeader(identity)},
      ),
    );
    final token = login.data!['AccessToken'] as String;
    final header = buildAuthorizationHeader(identity, token: token);
    final dio = Dio(
      BaseOptions(baseUrl: base.toString(), headers: {'Authorization': header}),
    );
    final userId =
        (login.data!['User'] as Map<String, dynamic>)['Id'] as String;
    return (
      SyncPlayClient(dio: dio, baseUrl: base, authorization: () => header),
      userId,
    );
  }

  Future<void> waitFor(bool Function() condition) async {
    for (var i = 0; i < 100 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(condition(), isTrue, reason: 'délai dépassé');
  }

  test(
    'soirée à deux sur un vrai serveur',
    () async {
      final config =
          jsonDecode(File(file!).readAsStringSync()) as Map<String, dynamic>;
      final base = Uri.parse(config['url'] as String);
      final users = (config['users'] as List).cast<Map<String, dynamic>>();
      final (alice, aliceId) = await signIn(base, users[0], 'alice');
      final (bob, _) = await signIn(base, users[1], 'bob');
      final bobMessages = <SyncPlayMessage>[];
      final aliceMessages = <SyncPlayMessage>[];
      final subs = [
        bob.messages.listen(bobMessages.add),
        alice.messages.listen(aliceMessages.add),
      ];
      alice.start();
      bob.start();
      await waitFor(() => alice.connected && bob.connected);
      await alice.syncTime();
      expect(alice.time.hasSamples, isTrue);

      await alice.create('Soirée des tests Dart');
      await waitFor(() => alice.group != null);
      final groups = await bob.list();
      await bob.join(groups.firstWhere((g) => g.id == alice.group!.id).id);
      await waitFor(
        () => bob.group != null && alice.group!.participants.length == 2,
      );

      final movies = await alice.dio.get<Map<String, dynamic>>(
        '/Items',
        queryParameters: {
          'Recursive': 'true',
          'IncludeItemTypes': 'Movie',
          'userId': aliceId,
        },
      );
      final movieId =
          ((movies.data!['Items'] as List).first as Map<String, dynamic>)['Id']
              as String;
      await alice.setQueue([movieId], start: const Duration(seconds: 30));
      await waitFor(() => bobMessages.whereType<QueueChanged>().isNotEmpty);
      final queue = bobMessages.whereType<QueueChanged>().last.queue;
      expect(queue.current!.itemId, movieId);
      expect(queue.start, const Duration(seconds: 30));

      await bob.unpause();
      await waitFor(
        () => aliceMessages.whereType<CommandReceived>().any(
          (c) => c.command.kind == SyncCommandKind.unpause,
        ),
      );
      await alice.seek(const Duration(minutes: 1));
      await waitFor(
        () => bobMessages.whereType<CommandReceived>().any(
          (c) => c.command.kind == SyncCommandKind.seek,
        ),
      );

      await bob.leave();
      await waitFor(() => alice.group!.participants.length == 1);
      await alice.leave();
      for (final s in subs) {
        await s.cancel();
      }
      await alice.dispose();
      await bob.dispose();
    },
    skip: available
        ? false
        : 'Pas de serveur Jellyfin de test (OPTIFIN_TEST_SERVER).',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
