import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:jellyfin_api/jellyfin_api.dart' hide PlayMethod;

import '../../../core/logging/app_log.dart';
import '../../../core/media/media_item.dart';
import '../../../core/media/media_mapper.dart';
import '../../../core/media/media_repository.dart';
import '../../../core/network/image_url.dart';
import '../../../core/storage/app_database.dart';
import '../../player/data/playback_repository.dart';
import '../../player/domain/playback_plan.dart';
import '../domain/download.dart';
import 'file_transfers.dart';

/// Fichier local prêt à lire hors connexion.
class LocalMedia {
  const LocalMedia({required this.file, required this.playbackInfo, required this.item});

  final File file;
  final PlaybackInfoResponse playbackInfo;
  final BaseItemDto item;
}

/// Téléchargements hors connexion d'un compte : fichier d'origine (lecture directe, aucune
/// perte), affiche et fond, fiche et `PlaybackInfo` conservées en base pour afficher et
/// lire sans réseau. Les transferts continuent en arrière-plan, app fermée.
class DownloadsRepository {
  DownloadsRepository({
    required AppDatabase db,
    required FileTransfers transfers,
    required this.accountId,
    this.media,
    this.playback,
    this.images,
    this.headers = const {},
  }) : _db = db, // ignore: prefer_initializing_formals
       // ignore: prefer_initializing_formals
       _transfers = transfers {
    _subscription = _transfers.updates.listen(_onUpdate);
    unawaited(_reconcileAll());
  }

  final AppDatabase _db;
  final FileTransfers _transfers;
  final String accountId;

  /// Absents hors session (lecture hors connexion seulement).
  final MediaRepository? media;
  final PlaybackRepository? playback;
  final JellyfinImageUrlBuilder? images;

  /// En-tête d'authentification : jamais de token dans une URL.
  final Map<String, String> headers;

  StreamSubscription<TransferUpdate>? _subscription;

  static const _dir = 'downloads';
  static String _posterTask(String id) => '$id~poster';
  static String _backdropTask(String id) => '$id~backdrop';

  void dispose() => unawaited(_subscription?.cancel());

  // ------------------------------------------------------------------ Lecture

  Stream<List<DownloadEntry>> watch() async* {
    final root = await _transfers.rootPath();
    yield* (_db.select(_db.downloads)
          ..where((t) => t.accountId.equals(accountId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch()
        .map((rows) => [for (final r in rows) ?_entry(r, root)]);
  }

  Stream<DownloadEntry?> watchItem(String itemId) async* {
    final root = await _transfers.rootPath();
    yield* (_db.select(_db.downloads)..where((t) => t.itemId.equals(itemId) & t.accountId.equals(accountId)))
        .watchSingleOrNull()
        .map((r) => r == null ? null : _entry(r, root));
  }

  DownloadEntry? _entry(DownloadRow r, String root) {
    try {
      final item = MediaMapper.fromDto(BaseItemDto.fromJson(jsonDecode(r.itemJson) as Map<String, dynamic>));
      return DownloadEntry(
        item: item,
        status: DownloadStatus.parse(r.status),
        progress: r.progress,
        sizeBytes: r.sizeBytes,
        filePath: '$root/${r.filePath}',
        posterPath: r.posterPath == null ? null : '$root/${r.posterPath}',
        backdropPath: r.backdropPath == null ? null : '$root/${r.backdropPath}',
        createdAt: r.createdAt,
      );
    } catch (_) {
      return null; // ligne illisible (format obsolète) : ignorée
    }
  }

  /// Fichier complet de [itemId], s'il existe encore sur l'appareil.
  Future<LocalMedia?> local(String itemId) async {
    final row = await (_db.select(
      _db.downloads,
    )..where((t) => t.itemId.equals(itemId) & t.accountId.equals(accountId))).getSingleOrNull();
    if (row == null) return null;
    if (DownloadStatus.parse(row.status) != DownloadStatus.complete && !await _reconcile(row)) return null;
    final file = File('${await _transfers.rootPath()}/${row.filePath}');
    if (!file.existsSync()) return null;
    try {
      return LocalMedia(
        file: file,
        playbackInfo: PlaybackInfoResponse.fromJson(jsonDecode(row.playbackJson) as Map<String, dynamic>),
        item: BaseItemDto.fromJson(jsonDecode(row.itemJson) as Map<String, dynamic>),
      );
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------ Actions

  /// Télécharge le fichier d'origine de [itemId] (film ou épisode).
  Future<void> add(String itemId, {bool wifiOnly = true}) async {
    final media = this.media, playback = this.playback, images = this.images;
    if (media == null || playback == null || images == null) throw StateError('Connexion requise');
    final existing = await (_db.select(_db.downloads)..where((t) => t.itemId.equals(itemId))).getSingleOrNull();
    if (existing != null && DownloadStatus.parse(existing.status) != DownloadStatus.failed) return;

    final (dto, info) = await (media.itemRaw(itemId), playback.downloadInfo(itemId)).wait;
    final plan = PlaybackRepository.planFromResponse(info, itemId: itemId, baseUrl: playback.baseUrl);
    if (plan.method != PlayMethod.directPlay) throw StateError('Fichier non téléchargeable');
    final item = MediaMapper.fromDto(dto);
    final ext = fileExtension(plan.container);
    final path = '$_dir/$itemId.$ext';

    await _db
        .into(_db.downloads)
        .insertOnConflictUpdate(
          DownloadsCompanion.insert(
            itemId: itemId,
            accountId: accountId,
            kind: item.kind.name,
            title: item.name,
            seriesId: Value(item.seriesId),
            seriesName: Value(item.seriesName),
            seasonNumber: Value(item.parentIndexNumber),
            episodeNumber: Value(item.indexNumber),
            itemJson: jsonEncode(dto.toJson()),
            playbackJson: jsonEncode(info.toJson()),
            filePath: path,
            sizeBytes: Value(info.mediaSources?.firstOrNull?.size ?? 0),
            status: DownloadStatus.queued.name,
            createdAt: DateTime.now(),
          ),
        );
    AppLog.i('downloads', 'Téléchargement de « ${item.name} » (${plan.container ?? '?'})');
    await _transfers.start(
      taskId: itemId,
      url: plan.streamUrl,
      relativePath: path,
      headers: headers,
      wifiOnly: wifiOnly,
      displayName: item.kind == MediaKind.episode ? '${item.seriesName ?? ''} · ${item.name}' : item.name,
    );

    // Affiche (épisode : vignette de l'épisode) et fond, pour la liste hors connexion.
    final poster = item.kind == MediaKind.episode ? item.primary : (item.poster ?? item.primary);
    final backdrop = item.backdrop;
    if (poster != null) {
      await _transfers.start(
        taskId: _posterTask(itemId),
        url: images.image(poster, logicalWidth: 240, devicePixelRatio: 3),
        relativePath: '$_dir/$itemId-poster.webp',
      );
    }
    if (backdrop != null) {
      await _transfers.start(
        taskId: _backdropTask(itemId),
        url: images.image(backdrop, logicalWidth: 640, devicePixelRatio: 2),
        relativePath: '$_dir/$itemId-backdrop.webp',
      );
    }
  }

  Future<void> addAll(Iterable<String> itemIds, {bool wifiOnly = true}) async {
    for (final id in itemIds) {
      try {
        await add(id, wifiOnly: wifiOnly);
      } catch (e) {
        AppLog.w('downloads', 'Épisode $id non téléchargé : $e');
      }
    }
  }

  Future<void> pause(String itemId) => _transfers.pause(itemId);

  Future<void> resume(String itemId) async {
    final row = await (_db.select(_db.downloads)..where((t) => t.itemId.equals(itemId))).getSingleOrNull();
    if (row == null) return;
    if (DownloadStatus.parse(row.status) == DownloadStatus.failed) {
      // Échec définitif : on recommence depuis le début.
      await _delete(row, keepRow: false);
      await add(itemId);
      return;
    }
    await _transfers.resume(itemId);
  }

  /// Annule (si en cours) et supprime fichiers et fiche.
  Future<void> remove(String itemId) async {
    final row = await (_db.select(_db.downloads)..where((t) => t.itemId.equals(itemId))).getSingleOrNull();
    if (row != null) await _delete(row, keepRow: false);
  }

  Future<void> removeAll({String? seriesId}) async {
    final rows =
        await (_db.select(_db.downloads)..where(
              (t) =>
                  t.accountId.equals(accountId) &
                  (seriesId == null ? const Constant(true) : t.seriesId.equals(seriesId)),
            ))
            .get();
    for (final r in rows) {
      await _delete(r, keepRow: false);
    }
  }

  Future<void> _delete(DownloadRow row, {required bool keepRow}) async {
    for (final id in [row.itemId, _posterTask(row.itemId), _backdropTask(row.itemId)]) {
      try {
        await _transfers.cancel(id);
      } catch (_) {}
    }
    final root = await _transfers.rootPath();
    for (final p in [
      row.filePath,
      row.posterPath,
      row.backdropPath,
      '$_dir/${row.itemId}-poster.webp',
      '$_dir/${row.itemId}-backdrop.webp',
    ]) {
      if (p == null) continue;
      try {
        final f = File('$root/$p');
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    if (!keepRow) await (_db.delete(_db.downloads)..where((t) => t.itemId.equals(row.itemId))).go();
  }

  // ------------------------------------------------------------------ Suivi des transferts

  /// Au démarrage : transferts terminés (ou en échec) pendant que l'app était fermée,
  /// dont l'état n'a pas pu être enregistré sur le moment.
  Future<void> _reconcileAll() async {
    try {
      final rows =
          await (_db.select(_db.downloads)..where(
                (t) =>
                    t.accountId.equals(accountId) &
                    t.status.isNotIn([DownloadStatus.complete.name, DownloadStatus.failed.name]),
              ))
              .get();
      for (final r in rows) {
        await _reconcile(r);
      }
    } catch (e) {
      AppLog.w('downloads', 'Rapprochement des téléchargements impossible : $e');
    }
  }

  /// Aligne une ligne sur l'état réel du transfert ; true si elle est désormais complète.
  Future<bool> _reconcile(DownloadRow row) async {
    TransferStatus? status;
    try {
      status = await _transfers.statusOf(row.itemId);
    } catch (_) {}
    final file = File('${await _transfers.rootPath()}/${row.filePath}');
    final complete =
        status == TransferStatus.complete || (status == null && row.progress >= 0.999 && file.existsSync());
    final next = complete
        ? DownloadStatus.complete
        : switch (status) {
            TransferStatus.failed => DownloadStatus.failed,
            TransferStatus.paused => DownloadStatus.paused,
            _ => null,
          };
    if (next != null && next.name != row.status) {
      AppLog.i('downloads', 'État rattrapé pour ${row.itemId} : ${next.name}');
      await (_db.update(_db.downloads)..where((t) => t.itemId.equals(row.itemId))).write(
        DownloadsCompanion(status: Value(next.name), progress: complete ? const Value(1) : const Value.absent()),
      );
    }
    return complete && file.existsSync();
  }

  Future<void> _onUpdate(TransferUpdate u) async {
    final id = u.taskId;
    if (id.endsWith('~poster') || id.endsWith('~backdrop')) {
      if (u.status != TransferStatus.complete) return;
      final itemId = id.substring(0, id.lastIndexOf('~'));
      final poster = id.endsWith('~poster');
      final path = '$_dir/$itemId-${poster ? 'poster' : 'backdrop'}.webp';
      await (_db.update(_db.downloads)..where((t) => t.itemId.equals(itemId))).write(
        poster ? DownloadsCompanion(posterPath: Value(path)) : DownloadsCompanion(backdropPath: Value(path)),
      );
      return;
    }
    final status = switch (u.status) {
      TransferStatus.queued => DownloadStatus.queued,
      TransferStatus.running => DownloadStatus.running,
      TransferStatus.paused => DownloadStatus.paused,
      TransferStatus.complete => DownloadStatus.complete,
      TransferStatus.failed => DownloadStatus.failed,
      TransferStatus.canceled || null => null,
    };
    if (u.status == TransferStatus.canceled) return;
    if (status == DownloadStatus.complete) AppLog.i('downloads', 'Téléchargement terminé ($id)');
    if (status == DownloadStatus.failed) AppLog.w('downloads', 'Téléchargement en échec ($id)');
    await (_db.update(_db.downloads)..where((t) => t.itemId.equals(id))).write(
      DownloadsCompanion(
        status: status == null ? const Value.absent() : Value(status.name),
        progress: status == DownloadStatus.complete
            ? const Value(1)
            : (u.progress == null ? const Value.absent() : Value(u.progress!)),
        // Pendant le téléchargement, la progression implique l'état « en cours ».
        sizeBytes: u.expectedBytes == null ? const Value.absent() : Value(u.expectedBytes!),
      ),
    );
    if (status == null && u.progress != null) {
      await (_db.update(_db.downloads)..where((t) => t.itemId.equals(id) & t.status.equals(DownloadStatus.queued.name)))
          .write(DownloadsCompanion(status: Value(DownloadStatus.running.name)));
    }
  }

  static String fileExtension(String? container) {
    final first = (container ?? '').split(',').first.trim().toLowerCase();
    return switch (first) {
      '' => 'mkv',
      'matroska' => 'mkv',
      'mpegts' => 'ts',
      'mov,mp4,m4a,3gp,3g2,mj2' || 'mov' => 'mov',
      _ => first,
    };
  }

  /// Espace utilisé par les téléchargements de ce compte.
  Future<int> usedBytes() async {
    final rows = await (_db.select(_db.downloads)..where((t) => t.accountId.equals(accountId))).get();
    return rows.fold<int>(
      0,
      (sum, r) =>
          sum +
          (DownloadStatus.parse(r.status) == DownloadStatus.complete
              ? r.sizeBytes
              : (r.sizeBytes * r.progress).round()),
    );
  }
}
