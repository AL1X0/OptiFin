import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_api/jellyfin_api.dart' hide PlayMethod;
import 'package:optifin/core/media/media_mapper.dart';
import 'package:optifin/core/storage/app_database.dart';
import 'package:optifin/features/downloads/data/downloads_repository.dart';
import 'package:optifin/features/downloads/data/file_transfers.dart';
import 'package:optifin/features/downloads/domain/download.dart';
import 'package:optifin/features/player/data/playback_preparer.dart';
import 'package:optifin/features/player/domain/engine_selector.dart';
import 'package:optifin/features/player/domain/playback_plan.dart';
import 'package:optifin/features/settings/domain/app_settings.dart';

import '../player/engine_matrix.dart';
import '../player/fakes.dart';
import '../player/playback_domain_test.dart' show response;

class FakeTransfers implements FileTransfers {
  FakeTransfers(this.root);

  final String root;
  final controller = StreamController<TransferUpdate>.broadcast();
  final canceled = <String>[];

  @override
  Stream<TransferUpdate> get updates => controller.stream;

  @override
  Future<String> rootPath() async => root;

  @override
  Future<void> start({
    required String taskId,
    required Uri url,
    required String relativePath,
    Map<String, String> headers = const {},
    bool wifiOnly = false,
    String? displayName,
  }) async {}

  @override
  Future<void> pause(String taskId) async {}

  @override
  Future<void> resume(String taskId) async {}

  @override
  Future<void> cancel(String taskId) async => canceled.add(taskId);
}

Map<String, Object?> _dto(String id, {String type = 'Movie', String? series, int? season, int? episode}) => {
  'Id': id,
  'Name': 'Titre $id',
  'Type': type,
  'SeriesId': ?series,
  'SeriesName': series == null ? null : 'Série $series',
  'ParentIndexNumber': ?season,
  'IndexNumber': ?episode,
};

DownloadEntry _entry(
  String id, {
  String type = 'Movie',
  String? series,
  int? season,
  int? episode,
  DateTime? at,
  DownloadStatus status = DownloadStatus.complete,
}) => DownloadEntry(
  item: MediaMapper.fromDto(
    BaseItemDto.fromJson(_dto(id, type: type, series: series, season: season, episode: episode)),
  ),
  status: status,
  progress: status == DownloadStatus.complete ? 1 : 0.5,
  sizeBytes: 1000,
  filePath: '/x/$id.mkv',
  createdAt: at ?? DateTime(2026),
);

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('Regroupement', () {
    test('films seuls, séries avec épisodes ordonnés, du plus récent au plus ancien', () {
      final groups = groupDownloads([
        _entry('film-ancien', at: DateTime(2026, 1)),
        _entry('e2', type: 'Episode', series: 's', season: 1, episode: 2, at: DateTime(2026, 3)),
        _entry('e1', type: 'Episode', series: 's', season: 1, episode: 1, at: DateTime(2026, 2)),
        _entry('e10', type: 'Episode', series: 's', season: 2, episode: 1, at: DateTime(2026, 4)),
        _entry('film-recent', at: DateTime(2026, 5)),
      ]);
      expect([for (final g in groups) g.id], ['film-recent', 's', 'film-ancien']);
      final series = groups[1];
      expect(series.isSeries, isTrue);
      expect(series.title, 'Série s');
      expect([for (final e in series.entries) e.itemId], ['e1', 'e2', 'e10']);
      expect(series.totalBytes, 3000);
    });

    test('tailles lisibles', () {
      expect(formatBytes(0), '0 Mo');
      expect(formatBytes(820 * 1024 * 1024), '820 Mo');
      expect(formatBytes((1.42 * 1024 * 1024 * 1024).round()), '1,4 Go');
    });

    test('extension du fichier selon le conteneur', () {
      expect(DownloadsRepository.fileExtension('mkv'), 'mkv');
      expect(DownloadsRepository.fileExtension('mov,mp4,m4a,3gp,3g2,mj2'), 'mov');
      expect(DownloadsRepository.fileExtension('mp4'), 'mp4');
      expect(DownloadsRepository.fileExtension(null), 'mkv');
    });
  });

  group('Dépôt', () {
    late AppDatabase db;
    late Directory dir;
    late FakeTransfers transfers;
    late DownloadsRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      dir = Directory.systemTemp.createTempSync('optifin_dl');
      transfers = FakeTransfers(dir.path);
      repo = DownloadsRepository(db: db, transfers: transfers, accountId: 'srv:u');
    });

    tearDown(() async {
      repo.dispose();
      await db.close();
      dir.deleteSync(recursive: true);
    });

    Future<void> insert(String id, {String status = 'queued'}) => db
        .into(db.downloads)
        .insert(
          DownloadsCompanion.insert(
            itemId: id,
            accountId: 'srv:u',
            kind: 'movie',
            title: 'Titre $id',
            itemJson: jsonEncode(_dto(id)),
            playbackJson: jsonEncode(response().toJson()),
            filePath: 'downloads/$id.mkv',
            status: status,
            createdAt: DateTime(2026),
          ),
        );

    test('suit la progression puis la fin du transfert', () async {
      await insert('m');
      transfers.controller.add(const TransferUpdate('m', progress: 0.4, expectedBytes: 5000));
      await _settle();
      var entry = (await repo.watch().first).single;
      expect(entry.status, DownloadStatus.running);
      expect(entry.progress, closeTo(0.4, 1e-9));
      expect(entry.sizeBytes, 5000);

      transfers.controller.add(const TransferUpdate('m', status: TransferStatus.paused));
      await _settle();
      expect((await repo.watch().first).single.status, DownloadStatus.paused);

      transfers.controller.add(const TransferUpdate('m', status: TransferStatus.complete));
      await _settle();
      entry = (await repo.watch().first).single;
      expect(entry.status, DownloadStatus.complete);
      expect(entry.progress, 1);
      expect(entry.filePath, '${dir.path}/downloads/m.mkv');
    });

    test('affiche enregistrée avec le téléchargement', () async {
      await insert('m', status: 'complete');
      transfers.controller.add(const TransferUpdate('m~poster', status: TransferStatus.complete));
      await _settle();
      expect((await repo.watch().first).single.posterPath, '${dir.path}/downloads/m-poster.webp');
    });

    test('lecture locale : seulement si complet et si le fichier existe encore', () async {
      await insert('m');
      expect(await repo.local('m'), isNull);
      await (db.update(
        db.downloads,
      )..where((t) => t.itemId.equals('m'))).write(const DownloadsCompanion(status: Value('complete')));
      expect(await repo.local('m'), isNull, reason: 'fichier absent');
      File('${dir.path}/downloads/m.mkv')
        ..createSync(recursive: true)
        ..writeAsStringSync('video');
      final local = await repo.local('m');
      expect(local, isNotNull);
      expect(local!.item.id, 'm');
      expect(local.playbackInfo.mediaSources?.single.id, 'src1');
    });

    test('suppression : transferts annulés, fichiers et fiche effacés', () async {
      await insert('m', status: 'complete');
      final file = File('${dir.path}/downloads/m.mkv')..createSync(recursive: true);
      await repo.remove('m');
      expect(file.existsSync(), isFalse);
      expect(transfers.canceled, containsAll(['m', 'm~poster', 'm~backdrop']));
      expect(await repo.watch().first, isEmpty);
    });

    test('chaque compte ne voit que ses téléchargements', () async {
      await insert('m');
      final other = DownloadsRepository(db: db, transfers: transfers, accountId: 'srv:autre');
      expect(await other.watch().first, isEmpty);
      other.dispose();
    });
  });

  group('Lecture d’un fichier téléchargé', () {
    test('aucune requête serveur, flux = fichier, lecture directe seulement', () async {
      final dir = Directory.systemTemp.createTempSync('optifin_local');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/x.mkv')..writeAsStringSync('video');
      final server = FakePlaybackRepository(
        ({audioIndex, subtitleIndex, options}) => throw StateError('le serveur ne doit pas être appelé'),
      );
      final preparer = PlaybackPreparer(
        repository: server,
        device: iphone15Pro.caps,
        settings: const AppSettings(),
        maxBitrate: 120000000,
        local: (_) async => LocalMedia(file: file, playbackInfo: response(), item: BaseItemDto.fromJson(_dto('x'))),
      );
      final prepared = await preparer.prepare('x');
      expect(server.prepareCalls, isEmpty);
      expect(prepared.plan.streamUrl.isScheme('file'), isTrue);
      expect(prepared.plan.method, PlayMethod.directPlay);
      expect(prepared.plan.subtitleTracks.any((t) => t.isExternal), isFalse);
      expect(prepared.selection.chain.every((d) => d.delivery == Delivery.directPlay), isTrue);
      // MKV + TrueHD : pas pour AVPlayer, mpv lit le fichier.
      expect(prepared.decision.engine, EngineKind.mpv);

      // Un repli reste sur le fichier (jamais de requête serveur).
      if (prepared.hasFallback) {
        final next = await preparer.planFor('x', prepared.selection, 1, probe: prepared.plan);
        expect(next.plan.streamUrl, prepared.plan.streamUrl);
      }
    });
  });
}
