import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'demo_library.dart';

/// Serveur Jellyfin simulé, en mémoire : répond aux vraies requêtes de l'app
/// (repositories, mappers, EngineSelector…) à partir de la bibliothèque fictive.
class DemoJellyfinAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final body = respond(o.method, o.uri.path.replaceFirst(RegExp('^/jf'), ''), o.uri.queryParametersAll);
    if (body == null) return ResponseBody.fromString('{}', 404, headers: _json);
    if (body == _noContent) return ResponseBody.fromString('', 204);
    return ResponseBody.fromString(jsonEncode(body), 200, headers: _json);
  }

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };
  static const _noContent = Object();

  @override
  void close({bool force = false}) {}

  // ------------------------------------------------------------ Routage

  Object? respond(String method, String path, Map<String, List<String>> q) {
    String? one(String k) => q[k]?.firstOrNull;
    List<String> many(String k) => [for (final v in q[k] ?? const <String>[]) ...v.split(',')];
    final seg = path.split('/').where((s) => s.isNotEmpty).toList();

    if (method == 'POST' && path.startsWith('/Sessions')) return _noContent;
    if (method == 'POST' && seg.length == 3 && seg[0] == 'Items' && seg[2] == 'PlaybackInfo') {
      return playbackInfo(seg[1]);
    }
    if (method == 'POST' && path.contains('FavoriteItems')) {
      return {'IsFavorite': true, 'Played': false, 'PlaybackPositionTicks': 0, 'PlayCount': 0, 'Key': seg.last};
    }
    if (method != 'GET') return _noContent;

    switch (seg) {
      case ['UserViews']:
        return result([libraryView('lib-films', 'Films', 'movies'), libraryView('lib-series', 'Séries', 'tvshows')]);
      case ['UserItems', 'Resume']:
        return result([
          for (final t in [...movies, ...episodes])
            if (t.progress > 0 && !t.played) dto(t),
        ]);
      case ['Shows', 'NextUp']:
        final seriesId = one('seriesId');
        final next = [
          titleById('veilleurs-s2e3'),
          titleById('kepler-s1e1'),
          titleById('rivages-s1e1'),
        ].where((e) => seriesId == null || e.seriesId == seriesId);
        return result([for (final e in next) dto(e)]);
      case ['Items', 'Latest']:
        final lib = one('parentId');
        final list = lib == 'lib-series' ? [...series] : [...movies];
        list.sort((a, b) => a.addedDaysAgo.compareTo(b.addedDaysAgo));
        return [for (final t in list.take(int.tryParse(one('limit') ?? '') ?? 16)) dto(t)];
      case ['Items', 'Filters']:
        return {
          'Genres': [
            for (final g in _genres) {'Name': g, 'Id': _genreId(g)},
          ],
        };
      case ['Items', 'Filters2'] || ['Items', 'Filters2', ...]:
        return {'Genres': _genres, 'Years': [2022, 2023, 2024, 2025], 'OfficialRatings': ['12', '16']};
      case ['Persons']:
        final term = _fold(one('searchTerm') ?? '');
        return result([
          for (final p in people)
            if (term.isEmpty || _fold(p.name).contains(term)) personDto(p),
        ]);
      case ['Items', final id, 'Similar']:
        return result([
          for (final m in movies)
            if (m.id != id) dto(m),
        ]);
      case ['Shows', final id, 'Seasons']:
        return result([
          for (final s in seasons)
            if (s.seriesId == id) dto(s),
        ]);
      case ['Shows', final id, 'Episodes']:
        return episodesOf(id, seasonId: one('seasonId'), startItemId: one('startItemId'), limit: one('limit'));
      case ['MediaSegments', final id]:
        return segmentsOf(id);
      case ['Items', final id] when id != 'Latest' && id != 'Filters':
        final person = people.where((p) => p.id == id).firstOrNull;
        if (person != null) return personDto(person, full: true);
        return dto(titleById(id), full: true);
      case ['Items']:
        return items(q, one, many);
    }
    return null;
  }

  Map<String, Object?> items(
    Map<String, List<String>> q,
    String? Function(String) one,
    List<String> Function(String) many,
  ) {
    final ids = many('ids');
    final fields = many('fields');
    if (ids.isNotEmpty) {
      return result([
        for (final id in ids)
          if (id == 'lib-films')
            libraryView(id, 'Films', 'movies')
          else if (id == 'lib-series')
            libraryView(id, 'Séries', 'tvshows')
          else
            dto(titleById(id), full: true, chapters: fields.contains('Chapters')),
      ]);
    }
    final types = many('includeItemTypes');
    var list = <DemoTitle>[
      if (types.isEmpty || types.contains('Movie')) ...movies,
      if (types.isEmpty || types.contains('Series')) ...series,
      if (types.contains('Episode')) ...episodes,
    ];
    final parent = one('parentId');
    if (parent == 'lib-films') list = [...movies];
    if (parent == 'lib-series') list = [...series];

    final term = one('searchTerm');
    if (term != null) {
      final t = _fold(term);
      list = list.where((e) => _fold(e.name).contains(t)).toList();
    }
    if (one('isFavorite') == 'true') list = list.where((e) => e.favorite).toList();
    if (many('filters').contains('IsUnplayed')) list = list.where((e) => !e.played).toList();

    final sort = many('sortBy');
    if (sort.contains('Random')) {
      // Tirage « aléatoire » reproductible pour la démo.
      const order = ['horizon', 'nebuleuse', 'veilleurs', 'neon', 'sommet', 'kepler', 'tempete', 'canyons'];
      list = [for (final id in order) ...list.where((e) => e.id == id)];
    } else if (sort.contains('DateCreated')) {
      list.sort((a, b) => a.addedDaysAgo.compareTo(b.addedDaysAgo));
    } else {
      list.sort((a, b) => _fold(a.name).compareTo(_fold(b.name)));
    }
    final lessThan = one('nameLessThan');
    if (lessThan != null) {
      return {'Items': <Object>[], 'TotalRecordCount': list.where((e) => _fold(e.name).compareTo(_fold(lessThan)) < 0).length};
    }
    final start = int.tryParse(one('startIndex') ?? '') ?? 0;
    final limit = int.tryParse(one('limit') ?? '') ?? list.length;
    return result([for (final t in list.skip(start).take(limit)) dto(t)], total: list.length);
  }

  Map<String, Object?> episodesOf(String seriesId, {String? seasonId, String? startItemId, String? limit}) {
    var list = episodes.where((e) => e.seriesId == seriesId && (seasonId == null || e.seasonId == seasonId)).toList();
    if (startItemId != null) {
      final i = list.indexWhere((e) => e.id == startItemId);
      if (i >= 0) list = list.sublist(i);
    }
    final n = int.tryParse(limit ?? '');
    return result([for (final e in n == null ? list : list.take(n)) dto(e)]);
  }

  Map<String, Object?> segmentsOf(String id) {
    final t = allTitles.where((e) => e.id == id).firstOrNull;
    if (t == null || t.type != 'Episode') return result(const []);
    final end = t.minutes * 60;
    Map<String, Object?> seg(String type, int from, int to) => {
      'Id': '$id-$type',
      'ItemId': id,
      'Type': type,
      'StartTicks': from * 10000000,
      'EndTicks': to * 10000000,
    };
    return result([seg('Recap', 5, 48), seg('Intro', 60, 138), seg('Outro', end - 95, end)]);
  }

  // ------------------------------------------------------------ Réponses

  static Map<String, Object?> result(List<Object?> items, {int? total}) => {
    'Items': items,
    'TotalRecordCount': total ?? items.length,
    'StartIndex': 0,
  };

  static Map<String, Object?> libraryView(String id, String name, String type) => {
    'Id': id,
    'Name': name,
    'Type': 'CollectionFolder',
    'CollectionType': type,
    'IsFolder': true,
    'ImageTags': {'Primary': 'p'},
    'PrimaryImageAspectRatio': 1.7777,
  };

  static Map<String, Object?> personDto(DemoPerson p, {bool full = false}) => {
    'Id': p.id,
    'Name': p.name,
    'Type': 'Person',
    'ImageTags': {'Primary': 'p'},
    if (full) 'Overview': '${p.name} est une figure fictive de la bibliothèque de démonstration d’OptiFin.',
  };

  static const _genres = ['Action', 'Aventure', 'Drame', 'Mystère', 'Romance', 'Science-fiction', 'Thriller', 'Western'];

  static String _genreId(String g) => 'g-${_fold(g).replaceAll(' ', '-')}';

  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ûüù]'), 'u')
      .replaceAll('’', "'");

  static int _ticks(int minutes) => minutes * 60 * 10000000;

  static Map<String, Object?> dto(DemoTitle t, {bool full = false, bool chapters = false}) {
    final runtime = _ticks(t.minutes);
    final isEpisode = t.type == 'Episode';
    final isSeason = t.type == 'Season';
    final parent = t.seriesId == null ? null : titleById(t.seriesId!);
    final seasonNumber = t.season ?? (isSeason ? t.index : null);
    return {
      'Id': t.id,
      'Name': t.name,
      'Type': t.type,
      'MediaType': t.type == 'Movie' || isEpisode ? 'Video' : 'Unknown',
      'IsFolder': t.type == 'Series' || isSeason,
      'ProductionYear': t.year,
      'PremiereDate': DateTime(t.year, 3 + (t.index ?? 1) % 9, 12).toIso8601String(),
      'DateCreated': DateTime(2026, 9, 28).subtract(Duration(days: t.addedDaysAgo)).toIso8601String(),
      if (!isSeason) 'CommunityRating': t.rating,
      if (!isSeason && !isEpisode) 'OfficialRating': t.officialRating,
      if (t.type != 'Series' && !isSeason) 'RunTimeTicks': runtime,
      'Overview': t.overview,
      if (t.tagline != null) 'Taglines': [t.tagline],
      'Genres': t.genres,
      'GenreItems': [
        for (final g in t.genres) {'Name': g, 'Id': _genreId(g)},
      ],
      'Studios': [
        {'Name': 'Productions OptiFin', 'Id': 'studio-optifin'},
      ],
      'ImageTags': {
        'Primary': 'p${t.variant}',
        if (t.type == 'Movie' || t.type == 'Series') 'Logo': 'l',
        if (t.type == 'Movie' || t.type == 'Series') 'Thumb': 't',
      },
      if (t.type == 'Movie' || t.type == 'Series') 'BackdropImageTags': ['b'],
      'PrimaryImageAspectRatio': isEpisode ? 1.7777 : 0.6667,
      if (t.type == 'Series') 'ChildCount': seasons.where((s) => s.seriesId == t.id).length,
      if (isSeason) 'ChildCount': episodes.where((e) => e.seasonId == t.id).length,
      'UserData': {
        'PlaybackPositionTicks': (runtime * t.progress).round(),
        if (t.progress > 0) 'PlayedPercentage': t.progress * 100,
        'Played': t.played,
        'IsFavorite': t.favorite,
        'PlayCount': t.played ? 1 : 0,
        'Key': t.id,
        if (t.type == 'Series')
          'UnplayedItemCount': episodes.where((e) => e.seriesId == t.id && !e.played).length,
      },
      if (parent != null) ...{
        'SeriesId': parent.id,
        'SeriesName': parent.name,
        'SeriesPrimaryImageTag': 'p${parent.variant}',
        'ParentBackdropItemId': parent.id,
        'ParentBackdropImageTags': ['b'],
        'ParentLogoItemId': parent.id,
        'ParentLogoImageTag': 'l',
        'ParentThumbItemId': parent.id,
        'ParentThumbImageTag': 't',
      },
      if (isEpisode) ...{
        'SeasonId': t.seasonId,
        'SeasonName': 'Saison $seasonNumber',
        'IndexNumber': t.index,
        'ParentIndexNumber': seasonNumber,
      },
      if (isSeason) 'IndexNumber': t.index,
      if (full && (t.type == 'Movie' || t.type == 'Series')) 'People': _people(t),
      if (full && (t.type == 'Movie' || isEpisode)) ...{
        'MediaStreams': _streams(t),
        'MediaSources': [_source(t)],
      },
      if (chapters && (t.type == 'Movie' || isEpisode)) 'Chapters': _chapters(t),
    };
  }

  static List<Map<String, Object?>> _people(DemoTitle t) {
    final seed = t.id.codeUnits.fold(0, (a, b) => a + b);
    final cast = [for (var i = 0; i < 5; i++) people[(seed + i) % 6]];
    const roles = ['Nora', 'Élias', 'Maya', 'Le commandant', 'Jonas'];
    return [
      for (final (i, p) in cast.indexed)
        {'Id': p.id, 'Name': p.name, 'Role': roles[i], 'Type': 'Actor', 'PrimaryImageTag': 'p'},
      {'Id': 'p-camille', 'Name': 'Camille Arnaud', 'Type': 'Director', 'PrimaryImageTag': 'p'},
    ];
  }

  static List<Map<String, Object?>> _chapters(DemoTitle t) {
    const names = ['Ouverture', 'Le départ', 'Premiers signes', 'Point de non-retour', 'La traversée', 'Final'];
    final step = t.minutes * 60 ~/ names.length;
    return [
      for (final (i, n) in names.indexed) {'StartPositionTicks': i * step * 10000000, 'Name': n},
    ];
  }

  static List<Map<String, Object?>> _streams(DemoTitle t) {
    final (codec, width, height, bits, range, dv) = switch (t.quality) {
      DemoQuality.uhdDolbyVision => ('hevc', 3840, 2160, 10, 'DOVIWithHDR10', 8),
      DemoQuality.uhdHdr10 => ('hevc', 3840, 2160, 10, 'HDR10', null),
      DemoQuality.fullHd => ('h264', 1920, 1080, 8, 'SDR', null),
    };
    Map<String, Object?> base(int index, String type) => {
      'Index': index,
      'Type': type,
      'IsInterlaced': false,
      'IsDefault': index <= 1,
      'IsForced': false,
      'IsHearingImpaired': false,
      'IsOriginal': false,
      'IsExternal': false,
      'IsTextSubtitleStream': type == 'Subtitle',
      'SupportsExternalStream': type == 'Subtitle',
    };
    return [
      {
        ...base(0, 'Video'),
        'Codec': codec,
        'Width': width,
        'Height': height,
        'BitDepth': bits,
        'VideoRange': range == 'SDR' ? 'SDR' : 'HDR',
        'VideoRangeType': range,
        'DvProfile': ?dv,
        'DvBlSignalCompatibilityId': dv == null ? null : 1,
        'AudioSpatialFormat': 'None',
        'DisplayTitle': '${height >= 2160 ? '4K' : '1080p'} ${range == 'SDR' ? '' : range}',
      },
      {
        ...base(1, 'Audio'),
        'Codec': 'eac3',
        'Channels': 6,
        'Language': 'fre',
        'AudioSpatialFormat': t.quality == DemoQuality.uhdDolbyVision ? 'DolbyAtmos' : 'None',
        'DisplayTitle': t.quality == DemoQuality.uhdDolbyVision ? 'Français - Dolby Atmos' : 'Français - E-AC3 5.1',
        'VideoRange': 'Unknown',
        'VideoRangeType': 'Unknown',
      },
      {
        ...base(2, 'Audio'),
        'Codec': 'eac3',
        'Channels': 6,
        'Language': 'eng',
        'AudioSpatialFormat': 'None',
        'DisplayTitle': 'English - E-AC3 5.1',
        'VideoRange': 'Unknown',
        'VideoRangeType': 'Unknown',
      },
      {
        ...base(3, 'Subtitle'),
        'Codec': 'srt',
        'Language': 'fre',
        'DisplayTitle': 'Français',
        'IsDefault': false,
        'DeliveryMethod': 'External',
        'DeliveryUrl': '/Videos/${t.id}/src/Subtitles/3/0/Stream.vtt',
        'VideoRange': 'Unknown',
        'VideoRangeType': 'Unknown',
        'AudioSpatialFormat': 'None',
      },
    ];
  }

  static Map<String, Object?> _source(DemoTitle t) => {
    'Id': 'src-${t.id}',
    'Protocol': 'File',
    'Type': 'Default',
    'Container': 'mp4',
    'Bitrate': t.quality == DemoQuality.fullHd ? 9000000 : 32000000,
    'RunTimeTicks': _ticks(t.minutes),
    'SupportsDirectPlay': true,
    'SupportsDirectStream': true,
    'SupportsTranscoding': true,
    'IsRemote': false,
    'ReadAtNativeFramerate': false,
    'IgnoreDts': false,
    'IgnoreIndex': false,
    'GenPtsInput': false,
    'SupportsProbing': true,
    'RequiresOpening': false,
    'RequiresClosing': false,
    'RequiresLooping': false,
    'IsInfiniteStream': false,
    'HasSegments': false,
    'MediaStreams': _streams(t),
    'DefaultAudioStreamIndex': 1,
  };

  static Map<String, Object?> playbackInfo(String id) => {
    'MediaSources': [_source(titleById(id))],
    'PlaySessionId': 'demo-$id',
  };
}
