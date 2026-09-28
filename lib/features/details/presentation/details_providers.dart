import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_item.dart';
import '../../../core/media/media_mapper.dart';
import '../../../core/media/media_repository.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../../downloads/presentation/downloads_providers.dart';
import '../../home/presentation/home_providers.dart';

final itemProvider = FutureProvider.autoDispose.family<MediaItem, String>((ref, id) async {
  try {
    return await ref.watch(mediaRepositoryProvider).item(id);
  } catch (e) {
    // Hors connexion : la fiche enregistrée avec le téléchargement.
    final local = await ref.read(downloadsRepositoryProvider).local(id).catchError((Object _) => null);
    if (local == null) rethrow;
    return MediaMapper.fromDto(local.item);
  }
});

final seasonsProvider = FutureProvider.autoDispose.family<List<MediaItem>, String>(
  (ref, seriesId) => ref.watch(mediaRepositoryProvider).seasons(seriesId),
);

final episodesProvider = FutureProvider.autoDispose.family<List<MediaItem>, (String, String)>(
  (ref, key) => ref.watch(mediaRepositoryProvider).episodes(key.$1, key.$2),
);

final nextUpForSeriesProvider = FutureProvider.autoDispose.family<MediaItem?, String>(
  (ref, seriesId) => ref.watch(mediaRepositoryProvider).nextUpFor(seriesId),
);

final similarProvider = FutureProvider.autoDispose.family<List<MediaItem>, String>(
  (ref, id) => ref.watch(mediaRepositoryProvider).similar(id),
);

final childrenProvider = FutureProvider.autoDispose.family<List<MediaItem>, String>(
  (ref, id) => ref.watch(mediaRepositoryProvider).children(id),
);

/// État utilisateur (vu / favori) avec mise à jour optimiste.
///
/// L'UI bascule immédiatement ; en cas d'échec serveur on revient à l'état
/// précédent et l'erreur remonte à l'appelant pour affichage.
final userStateProvider = NotifierProvider.autoDispose.family<UserStateController, UserState?, String>(
  UserStateController.new,
);

class UserStateController extends Notifier<UserState?> {
  UserStateController(this.itemId);

  final String itemId;

  @override
  UserState? build() => null; // null = utiliser l'état de l'élément chargé

  Future<void> toggleFavorite(UserState current) =>
      _apply(current.copyWith(favorite: !current.favorite), (repo) => repo.setFavorite(itemId, !current.favorite));

  Future<void> togglePlayed(UserState current) =>
      _apply(current.copyWith(played: !current.played), (repo) => repo.setPlayed(itemId, !current.played));

  Future<void> _apply(UserState optimistic, Future<UserState> Function(MediaRepository repo) call) async {
    final previous = state;
    state = optimistic;
    try {
      state = await call(ref.read(mediaRepositoryProvider));
      // Les rangées de l'accueil (Reprendre, À suivre, Favoris) en dépendent.
      ref.invalidate(homeProvider);
    } on ApiFailure {
      state = previous;
      rethrow;
    }
  }
}
