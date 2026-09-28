import 'dart:async';
import 'dart:convert';

import 'package:jellyfin_api/jellyfin_api.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/storage/app_database.dart';
import '../domain/home_data.dart';

/// Données brutes de l'accueil (DTO), sérialisables pour le cache.
class HomeSnapshot {
  const HomeSnapshot({
    required this.views,
    required this.featured,
    required this.resume,
    required this.nextUp,
    required this.latest,
    required this.favorites,
  });

  final List<BaseItemDto> views;
  final List<BaseItemDto> featured;
  final List<BaseItemDto> resume;
  final List<BaseItemDto> nextUp;

  /// viewId → derniers ajouts.
  final Map<String, List<BaseItemDto>> latest;
  final List<BaseItemDto> favorites;

  HomeSnapshot withFeatured(List<BaseItemDto> items) =>
      HomeSnapshot(views: views, featured: items, resume: resume, nextUp: nextUp, latest: latest, favorites: favorites);

  Map<String, Object?> toJson() => {
    'v': 1,
    'views': [for (final i in views) i.toJson()],
    'featured': [for (final i in featured) i.toJson()],
    'resume': [for (final i in resume) i.toJson()],
    'nextUp': [for (final i in nextUp) i.toJson()],
    'latest': {
      for (final e in latest.entries) e.key: [for (final i in e.value) i.toJson()],
    },
    'favorites': [for (final i in favorites) i.toJson()],
  };

  static HomeSnapshot? tryParse(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      if (json['v'] != 1) return null;
      List<BaseItemDto> list(Object? o) => [
        for (final e in (o as List<Object?>? ?? const [])) BaseItemDto.fromJson(e! as Map<String, Object?>),
      ];
      return HomeSnapshot(
        views: list(json['views']),
        featured: list(json['featured']),
        resume: list(json['resume']),
        nextUp: list(json['nextUp']),
        latest: {for (final e in (json['latest'] as Map<String, Object?>? ?? const {}).entries) e.key: list(e.value)},
        favorites: list(json['favorites']),
      );
    } catch (_) {
      return null; // cache corrompu ou format obsolète : ignoré
    }
  }
}

class HomeRepository {
  HomeRepository(this._media, this._cache, this._accountId);

  final MediaRepository _media;
  final ResponseCache _cache;
  final String _accountId;

  String get _key => '$_accountId/home';

  /// Émet l'accueil en cache (instantané) puis la version réseau.
  ///
  /// Si le réseau échoue alors qu'un cache a été affiché, l'erreur est avalée
  /// (l'utilisateur garde un accueil utilisable hors ligne).
  ///
  /// Carrousel aléatoire : la sélection affichée depuis le cache est conservée pour
  /// cette ouverture (pas de changement sous les yeux de l'utilisateur) ; la nouvelle
  /// sélection tirée au sort est enregistrée et apparaîtra à la prochaine ouverture.
  Stream<HomeData> watch() async* {
    final cachedRaw = await _cache.read(_key);
    final cached = cachedRaw == null ? null : HomeSnapshot.tryParse(cachedRaw);
    if (cached != null) yield buildHome(cached, fromCache: true);

    try {
      final fresh = await fetch();
      final shown = cached == null || cached.featured.isEmpty
          ? fresh
          : fresh.withFeatured(_stillUnwatched(cached, fresh));
      yield buildHome(shown, fromCache: false, upcoming: identical(shown, fresh) ? const [] : fresh.featured);
      unawaited(_cache.write(_key, jsonEncode(fresh.toJson())));
    } catch (e) {
      if (cached == null) rethrow;
    }
  }

  /// Sélection du cache, sans les titres commencés entre-temps (ils sont dans « Reprendre »).
  static List<BaseItemDto> _stillUnwatched(HomeSnapshot cached, HomeSnapshot fresh) {
    final started = {for (final i in fresh.resume) i.id, for (final i in fresh.nextUp) i.seriesId};
    final kept = cached.featured.where((i) => !started.contains(i.id)).toList();
    return kept.isEmpty ? fresh.featured : kept;
  }

  Future<HomeSnapshot> fetch() async {
    final views = await _media.userViewsRaw();
    final latestViews = views.where((v) => latestLibraryTypes.contains(v.collectionType)).toList();

    final (featured, resume, nextUp, favorites, latestLists) = await (
      _media.featuredRaw(),
      _media.resumeRaw(),
      _media.nextUpRaw(),
      _media.favoritesRaw(),
      // Une bibliothèque en échec ne doit pas faire tomber l'accueil entier.
      Future.wait([for (final v in latestViews) _media.latestRaw(v.id).catchError((_) => const <BaseItemDto>[])]),
    ).wait;

    // Déjà commencés : ils ont leur place dans « Reprendre » / « À suivre », pas en vitrine.
    final started = {for (final i in resume) i.id, for (final i in nextUp) i.seriesId};
    return HomeSnapshot(
      views: views,
      featured: featured.where((i) => !started.contains(i.id)).take(8).toList(),
      resume: resume,
      nextUp: nextUp,
      latest: {for (final (i, v) in latestViews.indexed) v.id: latestLists[i]},
      favorites: favorites,
    );
  }

  static const latestLibraryTypes = {
    BaseItemDtoCollectionType.movies,
    BaseItemDtoCollectionType.tvshows,
    BaseItemDtoCollectionType.music,
    BaseItemDtoCollectionType.musicvideos,
    BaseItemDtoCollectionType.homevideos,
  };
}
