import 'package:jellyfin_api/jellyfin_api.dart';

import '../../../core/logging/app_log.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/media/item_fields.dart';
import '../../../core/media/media_item.dart';
import '../../../core/media/media_mapper.dart';
import '../domain/playback_extras.dart';

/// Charge les compléments d'une lecture. Chaque partie est facultative : une
/// fonctionnalité absente du serveur (segments avant 10.10, trickplay non
/// généré…) donne simplement une liste vide, jamais une erreur de lecture.
class PlaybackExtrasRepository {
  PlaybackExtrasRepository(this._api, {required this.userId});

  final JellyfinClient _api;
  final String userId;

  Future<PlaybackExtras> load(MediaItem item, {String? mediaSourceId}) async {
    final results = await Future.wait<Object?>([
      _safe<BaseItemDto?>('chapitres/trickplay', () => _itemDetails(item.id)),
      _safe<List<MediaSegment>>('segments', () => _segments(item.id)),
      if (item.kind == MediaKind.episode && item.seriesId != null)
        _safe<MediaItem?>('épisode suivant', () => _nextEpisode(item)),
    ]);
    final dto = results[0] as BaseItemDto?;
    return PlaybackExtras(
      chapters: chaptersFrom(dto),
      trickplay: trickplayFrom(dto, mediaSourceId: mediaSourceId ?? item.id),
      segments: (results[1] as List<MediaSegment>?) ?? const [],
      nextEpisode: results.length > 2 ? results[2] as MediaItem? : null,
    );
  }

  Future<T?> _safe<T>(String what, Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      AppLog.w('extras', '$what indisponible : $e');
      return null;
    }
  }

  Future<BaseItemDto?> _itemDetails(String id) async {
    final r = await _api.library.getItems(
      userId: userId,
      ids: [id],
      fields: const [ItemFields.chapters, ItemFields.trickplay],
      enableImages: false,
      enableTotalRecordCount: false,
    );
    return r.items?.firstOrNull;
  }

  Future<List<MediaSegment>> _segments(String id) async {
    final r = await _api.mediaSegment.getItemSegments(itemId: id);
    return segmentsFrom(r.items ?? const []);
  }

  Future<MediaItem?> _nextEpisode(MediaItem item) async {
    final r = await _api.show.getEpisodes(
      seriesId: item.seriesId!,
      userId: userId,
      startItemId: item.id,
      limit: 2,
      fields: ItemFieldSets.episode,
      enableImageTypes: ItemFieldSets.cardImages,
      imageTypeLimit: 1,
    );
    final items = r.items ?? const [];
    // La liste commence à l'épisode courant ; le suivant est le deuxième.
    if (items.length < 2 || items.first.id != item.id) return null;
    return MediaMapper.fromDto(items[1]);
  }

  // ------------------------------------------------------------ Sous-titres distants

  /// Recherche via les fournisseurs installés sur le serveur. Les correspondances exactes d'abord.
  Future<List<RemoteSubtitle>> searchSubtitles(String itemId, String language) async {
    try {
      final r = await _api.subtitle.searchRemoteSubtitles(itemId: itemId, language: language);
      return remoteSubtitlesFrom(r);
    } catch (e) {
      throw ApiFailure.from(e);
    }
  }

  Future<void> downloadSubtitle(String itemId, String subtitleId) async {
    try {
      await _api.subtitle.downloadRemoteSubtitles(itemId: itemId, subtitleId: subtitleId);
    } catch (e) {
      throw ApiFailure.from(e);
    }
  }

  static List<RemoteSubtitle> remoteSubtitlesFrom(List<RemoteSubtitleInfo> infos) {
    final out = [
      for (final i in infos)
        if (i.id != null && i.id!.isNotEmpty)
          RemoteSubtitle(
            id: i.id!,
            name: (i.name?.trim().isNotEmpty ?? false) ? i.name!.trim() : 'Sous-titre ${i.id}',
            provider: i.providerName,
            format: i.format,
            language: i.threeLetterIsoLanguageName,
            downloads: i.downloadCount,
            rating: i.communityRating,
            hashMatch: i.isHashMatch ?? false,
            hearingImpaired: i.hearingImpaired ?? false,
            forced: i.forced ?? false,
          ),
    ];
    out.sort((a, b) {
      if (a.hashMatch != b.hashMatch) return a.hashMatch ? -1 : 1;
      return (b.downloads ?? 0).compareTo(a.downloads ?? 0);
    });
    return out;
  }

  // ------------------------------------------------------------ Mapping (pur)

  static List<Chapter> chaptersFrom(BaseItemDto? dto) {
    final chapters = dto?.chapters ?? const <ChapterInfo>[];
    return [
      for (final (i, c) in chapters.indexed)
        Chapter(
          index: i,
          start: Duration(microseconds: (c.startPositionTicks ?? 0) ~/ 10),
          name: (c.name?.trim().isNotEmpty ?? false) ? c.name!.trim() : 'Chapitre ${i + 1}',
          imageTag: c.imageTag,
        ),
    ]..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Choisit la résolution de vignettes la plus proche de 320 px (lisible et légère).
  static TrickplayManifest? trickplayFrom(BaseItemDto? dto, {required String mediaSourceId}) {
    final all = dto?.trickplay;
    if (all == null || all.isEmpty) return null;
    final byWidth = all[mediaSourceId] ?? all.values.whereType<Map<String, TrickplayInfoDto>>().firstOrNull;
    if (byWidth == null || byWidth.isEmpty) return null;
    final infos = byWidth.values.where((i) => (i.width ?? 0) > 0 && (i.interval ?? 0) > 0).toList()
      ..sort((a, b) => ((a.width! - 320).abs()).compareTo((b.width! - 320).abs()));
    final i = infos.firstOrNull;
    if (i == null) return null;
    return TrickplayManifest(
      width: i.width!,
      height: i.height ?? (i.width! * 9 ~/ 16),
      tileWidth: i.tileWidth ?? 10,
      tileHeight: i.tileHeight ?? 10,
      thumbnailCount: i.thumbnailCount ?? 0,
      interval: Duration(milliseconds: i.interval!),
    );
  }

  static List<MediaSegment> segmentsFrom(List<MediaSegmentDto> dtos) => [
    for (final d in dtos)
      if (_type(d.type) case final type?)
        if (d.startTicks != null && d.endTicks != null && d.endTicks! > d.startTicks!)
          MediaSegment(
            type: type,
            start: Duration(microseconds: d.startTicks! ~/ 10),
            end: Duration(microseconds: d.endTicks! ~/ 10),
          ),
  ]..sort((a, b) => a.start.compareTo(b.start));

  static SegmentType? _type(MediaSegmentDtoType? t) => switch (t) {
    MediaSegmentDtoType.intro => SegmentType.intro,
    MediaSegmentDtoType.recap => SegmentType.recap,
    MediaSegmentDtoType.preview => SegmentType.preview,
    MediaSegmentDtoType.commercial => SegmentType.commercial,
    MediaSegmentDtoType.outro => SegmentType.outro,
    _ => null,
  };
}
