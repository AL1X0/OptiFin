import 'dart:async';

import 'package:background_downloader/background_downloader.dart';
import 'package:path_provider/path_provider.dart';

/// Évolution d'un transfert (statut et/ou progression).
class TransferUpdate {
  const TransferUpdate(this.taskId, {this.status, this.progress, this.expectedBytes});

  final String taskId;
  final TransferStatus? status;

  /// 0..1 pendant le téléchargement.
  final double? progress;
  final int? expectedBytes;
}

enum TransferStatus { queued, running, paused, complete, failed, canceled }

/// Téléchargements de fichiers en arrière-plan (l'app peut être fermée).
/// Abstrait pour les tests.
abstract interface class FileTransfers {
  Stream<TransferUpdate> get updates;

  /// Dossier racine des fichiers téléchargés (absolu).
  Future<String> rootPath();

  /// [relativePath] : chemin relatif à [rootPath] (ex. `downloads/abc.mkv`).
  Future<void> start({
    required String taskId,
    required Uri url,
    required String relativePath,
    Map<String, String> headers,
    bool wifiOnly,
    String? displayName,
  });

  Future<void> pause(String taskId);
  Future<void> resume(String taskId);
  Future<void> cancel(String taskId);

  /// Dernier état connu d'un transfert (y compris terminé pendant que l'app était fermée).
  Future<TransferStatus?> statusOf(String taskId);
}

/// Implémentation `background_downloader` : URLSession d'arrière-plan sur iOS,
/// WorkManager sur Android ; pause et reprise (requêtes Range), relance automatique.
class BackgroundTransfers implements FileTransfers {
  BackgroundTransfers() {
    _downloader.updates.listen(_onUpdate);
    unawaited(_downloader.start());
  }

  final _downloader = FileDownloader();
  final _controller = StreamController<TransferUpdate>.broadcast();

  static const _base = BaseDirectory.applicationSupport;

  void _onUpdate(TaskUpdate update) {
    final id = update.task.taskId;
    switch (update) {
      case TaskStatusUpdate(:final status):
        _controller.add(TransferUpdate(id, status: _map(status)));
      case TaskProgressUpdate(:final progress, :final expectedFileSize):
        if (progress >= 0 && progress <= 1) {
          _controller.add(
            TransferUpdate(id, progress: progress, expectedBytes: expectedFileSize > 0 ? expectedFileSize : null),
          );
        }
    }
  }

  static TransferStatus _map(TaskStatus s) => switch (s) {
    TaskStatus.enqueued || TaskStatus.waitingToRetry => TransferStatus.queued,
    TaskStatus.running => TransferStatus.running,
    TaskStatus.paused => TransferStatus.paused,
    TaskStatus.complete => TransferStatus.complete,
    TaskStatus.canceled => TransferStatus.canceled,
    TaskStatus.notFound || TaskStatus.failed => TransferStatus.failed,
  };

  @override
  Stream<TransferUpdate> get updates => _controller.stream;

  @override
  Future<String> rootPath() async => (await getApplicationSupportDirectory()).path;

  @override
  Future<void> start({
    required String taskId,
    required Uri url,
    required String relativePath,
    Map<String, String> headers = const {},
    bool wifiOnly = false,
    String? displayName,
  }) async {
    final slash = relativePath.lastIndexOf('/');
    await _downloader.enqueue(
      DownloadTask(
        taskId: taskId,
        url: url.toString(),
        headers: headers,
        baseDirectory: _base,
        directory: slash < 0 ? '' : relativePath.substring(0, slash),
        filename: relativePath.substring(slash + 1),
        updates: Updates.statusAndProgress,
        requiresWiFi: wifiOnly,
        allowPause: true,
        retries: 3,
        displayName: displayName ?? '',
      ),
    );
  }

  Future<DownloadTask?> _task(String taskId) async {
    // En pause (ou après un redémarrage de l'app) : la tâche vit dans la base du downloader.
    final task = await _downloader.taskForId(taskId) ?? (await _downloader.database.recordForId(taskId))?.task;
    return task is DownloadTask ? task : null;
  }

  @override
  Future<void> pause(String taskId) async {
    final task = await _task(taskId);
    if (task != null) await _downloader.pause(task);
  }

  @override
  Future<void> resume(String taskId) async {
    final task = await _task(taskId);
    if (task != null) {
      await _downloader.resume(task);
    }
  }

  @override
  Future<void> cancel(String taskId) => _downloader.cancelTaskWithId(taskId);
  @override
  Future<TransferStatus?> statusOf(String taskId) async {
    final record = await _downloader.database.recordForId(taskId);
    return record == null ? null : _map(record.status);
  }
}
