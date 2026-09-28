import 'package:jellyfin_api/jellyfin_api.dart';

import '../../features/library/domain/library_pager.dart';
import '../../features/library/domain/library_query.dart';
import '../network/api_failure.dart';
import 'item_fields.dart';
import 'media_item.dart';
import 'media_mapper.dart';

/// Filtres disponibles pour une bibliothèque.
class LibraryFilterOptions {
  const LibraryFilterOptions({this.genres = const [], this.years = const []});

  final List<NamedRef> genres;
  final List<int> years;
}

/// Résultats de recherche groupés.
class SearchResults {
  const SearchResults({
    this.movies = const [],
    this.series = const [],
    this.episodes = const [],
    this.people = const [],
    this.artists = const [],
    this.albums = const [],
    this.songs = const [],
    this.others = const [],
  });

  final List<MediaItem> movies;
  final List<MediaItem> series;
  final List<MediaItem> episodes;
  final List<MediaItem> people;
  final List<MediaItem> artists;
  final List<MediaItem> albums;
  final List<MediaItem> songs;
  final List<MediaItem> others;

  bool get isEmpty =>
      movies.isEmpty &&
      series.isEmpty &&
      episodes.isEmpty &&
      people.isEmpty &&
      artists.isEmpty &&
      albums.isEmpty &&
      songs.isEmpty &&
      others.isEmpty;
}

/// Accès aux contenus pour l'utilisateur courant. Toutes les erreurs sortent en [ApiFailure].
class MediaRepository {
  MediaRepository(this._api, this.userId);

  final JellyfinClient _api;
  final String userId;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      throw ApiFailure.from(e);
    }
  }

  static List<MediaItem> _map(List<BaseItemDto>? items) => [
    for (final i in items ?? const <BaseItemDto>[]) MediaMapper.fromDto(i),
  ];

  // ---------------------------------------------------------------- Accueil

  Future<List<BaseItemDto>> userViewsRaw() => _guard(() async {
    final r = await _api.userView.getUserViews(userId: userId);
    return r.items ?? const [];
  });

  Future<List<BaseItemDto>> resumeRaw({int limit = 16}) => _guard(() async {
    final r = await _api.library.getResumeItems(
      userId: userId,
      limit: limit,
      mediaTypes: const [MediaType.video],
      fields: ItemFieldSets.card,
      enableImageTypes: ItemFieldSets.cardImages,
      imageTypeLimit: 1,
      enableTotalRecordCount: false,
    );
    return r.items ?? const [];
  });

  Future<List<BaseItemDto>> nextUpRaw({int limit = 16}) => _guard(() async {
    final r = await _api.show.getNextUp(
      userId: userId,
      limit: limit,
      fields: ItemFieldSets.card,
      enableImageTypes: ItemFieldSets.cardImages,
      imageTypeLimit: 1,
      enableTotalRecordCount: false,
      enableResumable: false,
      enableRewatching: false,
    );
    return r.items ?? const [];
  });

  Future<List<BaseItemDto>> latestRaw(String parentId, {int limit = 16}) => _guard(
    () => _api.library.getLatestMedia(
      userId: userId,
      parentId: parentId,
      limit: limit,
      groupItems: true,
      fields: ItemFieldSets.card,
      enableImageTypes: ItemFieldSets.cardImages,
      imageTypeLimit: 1,
    ),
  );

  /// Carrousel : recommandations au hasard parmi tous les films et séries non vus
  /// de toutes les bibliothèques (avec backdrop et synopsis pour un bel affichage).
  Future<List<BaseItemDto>> featuredRaw({int limit = 12}) => _guard(() async {
    final r = await _api.library.getItems(
      userId: userId,
      recursive: true,
      includeItemTypes: const [BaseItemKind.movie, BaseItemKind.series],
      imageTypes: const [ImageType.backdrop],
      filters: const [ItemFilter.isUnplayed],
      hasOverview: true,
      sortBy: const [ItemSortBy.random],
      limit: limit,
      fields: ItemFieldSets.featured,
      enableImageTypes: const [ImageType.backdrop, ImageType.logo, ImageType.primary],
      imageTypeLimit: 1,
      enableTotalRecordCount: false,
    );
    return r.items ?? const [];
  });

  Future<List<BaseItemDto>> favoritesRaw({int limit = 20}) => _guard(() async {
    final r = await _api.library.getItems(
      userId: userId,
      recursive: true,
      isFavorite: true,
      includeItemTypes: const [BaseItemKind.movie, BaseItemKind.series, BaseItemKind.episode, BaseItemKind.boxSet],
      sortBy: const [ItemSortBy.datePlayed, ItemSortBy.sortName],
      sortOrder: const [SortOrder.descending],
      limit: limit,
      fields: ItemFieldSets.card,
      enableImageTypes: ItemFieldSets.cardImages,
      imageTypeLimit: 1,
      enableTotalRecordCount: false,
    );
    return r.items ?? const [];
  });

  Future<List<MediaItem>> userViews() async => _map(await userViewsRaw());

  // ---------------------------------------------------------------- Fiches

  Future<MediaItem> item(String id) async => MediaMapper.fromDto(await itemRaw(id));

  /// Fiche brute (DTO), conservée telle quelle pour les téléchargements hors connexion.
  Future<BaseItemDto> itemRaw(String id) => _guard(() async {
    // getItem n'accepte pas `fields` : on passe par /Items?ids= pour contrôler la réponse.
    final r = await _api.library.getItems(
      userId: userId,
      ids: [id],
      fields: ItemFieldSets.detail,
      enableTotalRecordCount: false,
    );
    final dto = r.items?.firstOrNull;
    if (dto == null) throw const UnexpectedFailure('Élément introuvable');
    return dto;
  });

  /// Personne : /Items/{id} renvoie la biographie complète (les personnes ne sont
  /// pas toujours retournées par /Items?ids=).
  Future<MediaItem> person(String id) =>
      _guard(() async => MediaMapper.fromDto(await _api.library.getItem(itemId: id, userId: userId)));

  Future<List<MediaItem>> seasons(String seriesId) => _guard(() async {
    final r = await _api.show.getSeasons(
      seriesId: seriesId,
      userId: userId,
      fields: ItemFieldSets.card,
      enableImageTypes: ItemFieldSets.cardImages,
    );
    return _map(r.items);
  });

  Future<List<MediaItem>> episodes(String seriesId, String seasonId) => _guard(() async {
    final r = await _api.show.getEpisodes(
      seriesId: seriesId,
      seasonId: seasonId,
      userId: userId,
      fields: ItemFieldSets.episode,
      enableImageTypes: const [ImageType.primary, ImageType.thumb],
    );
    return _map(r.items);
  });

  /// Épisode à reprendre / suivant d'une série (bouton Lecture de la fiche série).
  Future<MediaItem?> nextUpFor(String seriesId) => _guard(() async {
    final r = await _api.show.getNextUp(
      userId: userId,
      seriesId: seriesId,
      limit: 1,
      fields: ItemFieldSets.episode,
      enableResumable: true,
      enableTotalRecordCount: false,
    );
    final dto = r.items?.firstOrNull;
    return dto == null ? null : MediaMapper.fromDto(dto);
  });

  Future<List<MediaItem>> similar(String id, {int limit = 16}) => _guard(() async {
    final r = await _api.library.getSimilarItems(itemId: id, userId: userId, limit: limit, fields: ItemFieldSets.card);
    return _map(r.items);
  });

  Future<List<MediaItem>> children(String parentId, {int limit = 200}) => _guard(() async {
    final r = await _api.library.getItems(
      userId: userId,
      parentId: parentId,
      sortBy: const [ItemSortBy.premiereDate, ItemSortBy.sortName],
      limit: limit,
      fields: ItemFieldSets.card,
      enableImageTypes: ItemFieldSets.cardImages,
      imageTypeLimit: 1,
    );
    return _map(r.items);
  });

  // ---------------------------------------------------------------- Bibliothèques

  Future<PageResult<MediaItem>> page(LibraryQuery q, int startIndex, int limit) => _guard(() async {
    final r = await _api.library.getItems(
      userId: userId,
      parentId: q.parentId,
      recursive: q.recursive,
      includeItemTypes: q.kinds.isEmpty ? null : [for (final k in q.kinds) ?baseItemKindOf(k)],
      sortBy: sortFieldsFor(q.sort),
      sortOrder: [q.descending ? SortOrder.descending : SortOrder.ascending],
      isPlayed: q.played,
      isFavorite: q.favoritesOnly ? true : null,
      genreIds: q.genreIds.isEmpty ? null : q.genreIds,
      studioIds: q.studioIds.isEmpty ? null : q.studioIds,
      personIds: q.personIds.isEmpty ? null : q.personIds,
      years: q.years.isEmpty ? null : q.years,
      isHd: q.resolution == ResolutionFilter.hd ? true : null,
      is4K: q.resolution == ResolutionFilter.uhd ? true : null,
      startIndex: startIndex,
      limit: limit,
      fields: ItemFieldSets.card,
      enableImageTypes: ItemFieldSets.cardImages,
      imageTypeLimit: 1,
      enableTotalRecordCount: true,
    );
    return PageResult(_map(r.items), r.totalRecordCount ?? r.items?.length ?? 0);
  });

  /// Position du premier élément dont le titre commence à [letter] ou après.
  /// Nécessite un tri par titre croissant ([LibraryQuery.supportsAlphaIndex]).
  Future<int> indexOfLetter(LibraryQuery q, String letter) => _guard(() async {
    if (letter == '#') return 0;
    final r = await _api.library.getItems(
      userId: userId,
      parentId: q.parentId,
      recursive: q.recursive,
      includeItemTypes: q.kinds.isEmpty ? null : [for (final k in q.kinds) ?baseItemKindOf(k)],
      isPlayed: q.played,
      isFavorite: q.favoritesOnly ? true : null,
      genreIds: q.genreIds.isEmpty ? null : q.genreIds,
      studioIds: q.studioIds.isEmpty ? null : q.studioIds,
      personIds: q.personIds.isEmpty ? null : q.personIds,
      years: q.years.isEmpty ? null : q.years,
      isHd: q.resolution == ResolutionFilter.hd ? true : null,
      is4K: q.resolution == ResolutionFilter.uhd ? true : null,
      nameLessThan: letter,
      limit: 0,
      enableImages: false,
      enableTotalRecordCount: true,
    );
    return r.totalRecordCount ?? 0;
  });

  Future<LibraryFilterOptions> filterOptions(LibraryQuery q) => _guard(() async {
    final kinds = q.kinds.isEmpty ? null : [for (final k in q.kinds) ?baseItemKindOf(k)];
    final (filters, legacy) = await (
      _api.filter.getQueryFilters(userId: userId, parentId: q.parentId, includeItemTypes: kinds),
      _api.filter.getQueryFiltersLegacy(userId: userId, parentId: q.parentId, includeItemTypes: kinds),
    ).wait;
    final years = [...?legacy.years]..sort((a, b) => b.compareTo(a));
    return LibraryFilterOptions(
      genres: [
        for (final g in filters.genres ?? const <NameGuidPair>[])
          if (g.id != null && g.name != null) NamedRef(id: g.id!, name: g.name!),
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      years: years,
    );
  });

  // ---------------------------------------------------------------- Recherche

  Future<SearchResults> search(String term) => _guard(() async {
    Future<List<MediaItem>> byKind(List<BaseItemKind> kinds, {int limit = 20}) async {
      final r = await _api.library.getItems(
        userId: userId,
        searchTerm: term,
        recursive: true,
        includeItemTypes: kinds,
        limit: limit,
        fields: ItemFieldSets.card,
        enableImageTypes: ItemFieldSets.cardImages,
        imageTypeLimit: 1,
        enableTotalRecordCount: false,
      );
      return _map(r.items);
    }

    Future<List<MediaItem>> people() async {
      final r = await _api.person.getPersons(
        searchTerm: term,
        userId: userId,
        limit: 20,
        enableImageTypes: const [ImageType.primary],
      );
      return _map(r.items);
    }

    final results = await [
      byKind(const [BaseItemKind.movie]),
      byKind(const [BaseItemKind.series]),
      byKind(const [BaseItemKind.episode]),
      people(),
      byKind(const [BaseItemKind.musicArtist]),
      byKind(const [BaseItemKind.musicAlbum]),
      byKind(const [BaseItemKind.audio]),
      byKind(const [BaseItemKind.boxSet, BaseItemKind.playlist, BaseItemKind.video, BaseItemKind.musicVideo]),
    ].wait;
    return SearchResults(
      movies: results[0],
      series: results[1],
      episodes: results[2],
      people: results[3],
      artists: results[4],
      albums: results[5],
      songs: results[6],
      others: results[7],
    );
  });

  // ---------------------------------------------------------------- Actions

  Future<UserState> setFavorite(String id, bool favorite) => _guard(() async {
    final d = favorite
        ? await _api.userData.markFavoriteItem(itemId: id, userId: userId)
        : await _api.userData.unmarkFavoriteItem(itemId: id, userId: userId);
    return _userState(d);
  });

  Future<UserState> setPlayed(String id, bool played) => _guard(() async {
    final d = played
        ? await _api.userData.markPlayedItem(itemId: id, userId: userId)
        : await _api.userData.markUnplayedItem(itemId: id, userId: userId);
    return _userState(d);
  });

  static UserState _userState(UserItemDataDto d) => UserState(
    played: d.played ?? false,
    favorite: d.isFavorite ?? false,
    positionTicks: d.playbackPositionTicks ?? 0,
    playedPercentage: d.playedPercentage,
    unplayedCount: d.unplayedItemCount,
  );

  // ---------------------------------------------------------------- Mappings

  static BaseItemKind? baseItemKindOf(MediaKind kind) => switch (kind) {
    MediaKind.movie => BaseItemKind.movie,
    MediaKind.series => BaseItemKind.series,
    MediaKind.season => BaseItemKind.season,
    MediaKind.episode => BaseItemKind.episode,
    MediaKind.boxSet => BaseItemKind.boxSet,
    MediaKind.folder => BaseItemKind.folder,
    MediaKind.collectionFolder => BaseItemKind.collectionFolder,
    MediaKind.person => BaseItemKind.person,
    MediaKind.musicAlbum => BaseItemKind.musicAlbum,
    MediaKind.musicArtist => BaseItemKind.musicArtist,
    MediaKind.audio => BaseItemKind.audio,
    MediaKind.playlist => BaseItemKind.playlist,
    MediaKind.video => BaseItemKind.video,
    MediaKind.musicVideo => BaseItemKind.musicVideo,
    MediaKind.photo => BaseItemKind.photo,
    MediaKind.photoAlbum => BaseItemKind.photoAlbum,
    MediaKind.trailer => BaseItemKind.trailer,
    MediaKind.tvChannel => BaseItemKind.tvChannel,
    MediaKind.other => null,
  };

  /// Tri principal + départage par titre pour un ordre stable entre pages.
  static List<ItemSortBy> sortFieldsFor(LibrarySort sort) => switch (sort) {
    LibrarySort.title => const [ItemSortBy.sortName],
    LibrarySort.dateAdded => const [ItemSortBy.dateCreated, ItemSortBy.sortName],
    LibrarySort.premiereDate => const [ItemSortBy.premiereDate, ItemSortBy.sortName],
    LibrarySort.rating => const [ItemSortBy.communityRating, ItemSortBy.sortName],
    LibrarySort.runtime => const [ItemSortBy.runtime, ItemSortBy.sortName],
    LibrarySort.year => const [ItemSortBy.productionYear, ItemSortBy.sortName],
  };
}
