import '../../../core/media/media_item.dart';
import '../../../core/media/media_mapper.dart';
import '../data/home_repository.dart';

enum CardStyle { poster, landscape, square }

class HomeSection {
  const HomeSection({required this.id, required this.title, required this.style, required this.items, this.library});

  final String id;
  final String title;
  final CardStyle style;
  final List<MediaItem> items;

  /// Bibliothèque à ouvrir via « Tout voir ».
  final MediaItem? library;
}

class HomeData {
  const HomeData({required this.featured, required this.sections, required this.libraries, required this.fromCache});

  final List<MediaItem> featured;
  final List<HomeSection> sections;
  final List<MediaItem> libraries;
  final bool fromCache;

  bool get isEmpty => featured.isEmpty && sections.isEmpty;
}

/// Compose l'accueil à partir des données brutes. Pur et testé.
///
/// Ordre : Reprendre → À suivre → Ajouts récents (par bibliothèque, dans l'ordre
/// du serveur) → Favoris. Les rangées vides sont omises. « À suivre » exclut les
/// épisodes déjà présents dans « Reprendre ».
HomeData buildHome(HomeSnapshot s, {required bool fromCache}) {
  final libraries = [for (final v in s.views) MediaMapper.fromDto(v)];
  final resume = [for (final i in s.resume) MediaMapper.fromDto(i)];
  final resumeIds = {for (final i in resume) i.id};
  final nextUp = [
    for (final i in s.nextUp)
      if (!resumeIds.contains(i.id)) MediaMapper.fromDto(i),
  ];

  final sections = <HomeSection>[
    if (resume.isNotEmpty) HomeSection(id: 'resume', title: 'Reprendre', style: CardStyle.landscape, items: resume),
    if (nextUp.isNotEmpty) HomeSection(id: 'nextUp', title: 'À suivre', style: CardStyle.landscape, items: nextUp),
    for (final lib in libraries)
      if (s.latest[lib.id] case final items? when items.isNotEmpty)
        HomeSection(
          id: 'latest-${lib.id}',
          title: 'Ajouts récents · ${lib.name}',
          style: styleForLibrary(lib.libraryType),
          items: [for (final i in items) MediaMapper.fromDto(i)],
          library: lib,
        ),
    if (s.favorites.isNotEmpty)
      HomeSection(
        id: 'favorites',
        title: 'Favoris',
        style: CardStyle.poster,
        items: [for (final i in s.favorites) MediaMapper.fromDto(i)],
      ),
  ];

  return HomeData(
    featured: [
      for (final i in s.featured)
        if (MediaMapper.fromDto(i) case final item when item.backdrops.isNotEmpty) item,
    ],
    sections: sections,
    libraries: libraries,
    fromCache: fromCache,
  );
}

CardStyle styleForLibrary(LibraryType? type) => switch (type) {
      LibraryType.music => CardStyle.square,
      LibraryType.homevideos || LibraryType.musicvideos || LibraryType.photos => CardStyle.landscape,
      _ => CardStyle.poster,
    };
