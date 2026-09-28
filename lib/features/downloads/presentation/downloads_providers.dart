import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../player/presentation/playback_providers.dart';
import '../data/downloads_repository.dart';
import '../data/file_transfers.dart';
import '../domain/download.dart';

/// Moteur de transferts en arrière-plan, unique pour toute l'app.
final fileTransfersProvider = Provider<FileTransfers>((ref) => BackgroundTransfers());

final downloadsRepositoryProvider = Provider<DownloadsRepository>((ref) {
  final session = ref.watch(sessionControllerProvider);
  if (session == null) throw StateError('Aucune session active');
  final repo = DownloadsRepository(
    db: ref.watch(appDatabaseProvider),
    transfers: ref.watch(fileTransfersProvider),
    accountId: session.account.id,
    media: ref.watch(mediaRepositoryProvider),
    playback: ref.watch(playbackRepositoryProvider),
    images: ref.watch(imageUrlBuilderProvider),
    headers: ref.watch(playbackHeadersProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// Tous les téléchargements du compte, regroupés (films, séries).
final downloadsProvider = StreamProvider<List<DownloadEntry>>((ref) => ref.watch(downloadsRepositoryProvider).watch());

final downloadGroupsProvider = Provider<AsyncValue<List<DownloadGroup>>>(
  (ref) => ref.watch(downloadsProvider).whenData(groupDownloads),
);

/// État du téléchargement d'un élément (null = pas téléchargé).
final downloadForItemProvider = StreamProvider.family<DownloadEntry?, String>(
  (ref, itemId) => ref.watch(downloadsRepositoryProvider).watchItem(itemId),
);
