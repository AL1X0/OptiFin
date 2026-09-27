import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_item.dart';
import '../../../core/media/media_repository.dart';
import '../../../core/providers.dart';
import '../../home/domain/home_data.dart';
import '../domain/library_query.dart';

/// Bibliothèques de l'utilisateur (onglet Bibliothèques).
final userViewsProvider = FutureProvider.autoDispose<List<MediaItem>>(
  (ref) => ref.watch(mediaRepositoryProvider).userViews(),
);

/// Origine d'un écran de parcours.
sealed class LibrarySource {
  const LibrarySource();
}

class ViewSource extends LibrarySource {
  const ViewSource(this.id);
  final String id;

  @override
  bool operator ==(Object other) => other is ViewSource && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class GenreSource extends LibrarySource {
  const GenreSource(this.id, this.name);
  final String id;
  final String name;

  @override
  bool operator ==(Object other) => other is GenreSource && other.id == id;
  @override
  int get hashCode => Object.hash('genre', id);
}

class StudioSource extends LibrarySource {
  const StudioSource(this.id, this.name);
  final String id;
  final String name;

  @override
  bool operator ==(Object other) => other is StudioSource && other.id == id;
  @override
  int get hashCode => Object.hash('studio', id);
}

/// Contexte résolu d'un parcours : titre, requête initiale, style de carte.
class LibraryContext {
  const LibraryContext({required this.title, required this.query, required this.style});

  final String title;
  final LibraryQuery query;
  final CardStyle style;
}

final libraryContextProvider = FutureProvider.autoDispose.family<LibraryContext, LibrarySource>((ref, source) async {
  switch (source) {
    case ViewSource(:final id):
      final view = await ref.watch(mediaRepositoryProvider).item(id);
      final type = view.libraryType;
      return LibraryContext(
        title: view.name,
        query: LibraryQuery(parentId: id, kinds: defaultKindsFor(type), recursive: recursiveFor(type)),
        style: styleForLibrary(type),
      );
    case GenreSource(:final id, :final name):
      return LibraryContext(
        title: name,
        query: LibraryQuery(genreIds: [id], kinds: const [MediaKind.movie, MediaKind.series]),
        style: CardStyle.poster,
      );
    case StudioSource(:final id, :final name):
      return LibraryContext(
        title: name,
        query: LibraryQuery(studioIds: [id], kinds: const [MediaKind.movie, MediaKind.series]),
        style: CardStyle.poster,
      );
  }
});

final libraryFilterOptionsProvider = FutureProvider.autoDispose.family<LibraryFilterOptions, LibraryQuery>(
  (ref, query) => ref.watch(mediaRepositoryProvider).filterOptions(query.clearFilters()),
);
