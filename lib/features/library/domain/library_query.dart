import '../../../core/media/media_item.dart';

enum LibrarySort {
  title('Titre'),
  dateAdded('Date d’ajout'),
  premiereDate('Date de sortie'),
  rating('Note'),
  runtime('Durée'),
  year('Année');

  const LibrarySort(this.label);
  final String label;

  /// Sens par défaut quand on choisit ce tri (récent/meilleur d'abord).
  bool get defaultDescending => this != title;
}

enum ResolutionFilter { any, hd, uhd }

/// Requête de parcours de bibliothèque : immuable, comparable (clé de provider).
class LibraryQuery {
  const LibraryQuery({
    this.parentId,
    this.kinds = const [],
    this.recursive = true,
    this.sort = LibrarySort.title,
    this.descending = false,
    this.played,
    this.favoritesOnly = false,
    this.genreIds = const [],
    this.studioIds = const [],
    this.personIds = const [],
    this.years = const [],
    this.resolution = ResolutionFilter.any,
  });

  final String? parentId;
  final List<MediaKind> kinds;
  final bool recursive;
  final LibrarySort sort;
  final bool descending;

  /// null = tous, true = vus, false = non vus.
  final bool? played;
  final bool favoritesOnly;
  final List<String> genreIds;
  final List<String> studioIds;
  final List<String> personIds;
  final List<int> years;
  final ResolutionFilter resolution;

  /// L'index alphabétique n'a de sens que trié par titre croissant.
  bool get supportsAlphaIndex => sort == LibrarySort.title && !descending;

  int get activeFilterCount =>
      (played != null ? 1 : 0) +
      (favoritesOnly ? 1 : 0) +
      (genreIds.isNotEmpty ? 1 : 0) +
      (years.isNotEmpty ? 1 : 0) +
      (resolution != ResolutionFilter.any ? 1 : 0);

  LibraryQuery copyWith({
    LibrarySort? sort,
    bool? descending,
    bool? Function()? played,
    bool? favoritesOnly,
    List<String>? genreIds,
    List<int>? years,
    ResolutionFilter? resolution,
  }) => LibraryQuery(
    parentId: parentId,
    kinds: kinds,
    recursive: recursive,
    sort: sort ?? this.sort,
    descending: descending ?? this.descending,
    played: played != null ? played() : this.played,
    favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    genreIds: genreIds ?? this.genreIds,
    studioIds: studioIds,
    personIds: personIds,
    years: years ?? this.years,
    resolution: resolution ?? this.resolution,
  );

  LibraryQuery clearFilters() => LibraryQuery(
    parentId: parentId,
    kinds: kinds,
    recursive: recursive,
    sort: sort,
    descending: descending,
    studioIds: studioIds,
    personIds: personIds,
  );

  @override
  bool operator ==(Object other) =>
      other is LibraryQuery &&
      other.parentId == parentId &&
      _eq(other.kinds, kinds) &&
      other.recursive == recursive &&
      other.sort == sort &&
      other.descending == descending &&
      other.played == played &&
      other.favoritesOnly == favoritesOnly &&
      _eq(other.genreIds, genreIds) &&
      _eq(other.studioIds, studioIds) &&
      _eq(other.personIds, personIds) &&
      _eq(other.years, years) &&
      other.resolution == resolution;

  @override
  int get hashCode => Object.hash(
    parentId,
    Object.hashAll(kinds),
    recursive,
    sort,
    descending,
    played,
    favoritesOnly,
    Object.hashAll(genreIds),
    Object.hashAll(studioIds),
    Object.hashAll(personIds),
    Object.hashAll(years),
    resolution,
  );

  static bool _eq<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Types d'éléments par défaut selon le type de bibliothèque.
List<MediaKind> defaultKindsFor(LibraryType? type) => switch (type) {
  LibraryType.movies => const [MediaKind.movie],
  LibraryType.tvshows => const [MediaKind.series],
  LibraryType.boxsets => const [MediaKind.boxSet],
  LibraryType.music => const [MediaKind.musicAlbum],
  LibraryType.musicvideos => const [MediaKind.musicVideo],
  LibraryType.playlists => const [MediaKind.playlist],
  _ => const [],
};

/// Parcours récursif (vue à plat) ou par dossiers selon le type de bibliothèque.
bool recursiveFor(LibraryType? type) => switch (type) {
  LibraryType.homevideos || LibraryType.photos || LibraryType.folders || LibraryType.unknown || null => false,
  _ => true,
};
