import 'package:jellyfin_api/jellyfin_api.dart' hide PersonKind, VideoRange;

import 'media_item.dart';

/// Conversion `BaseItemDto` → [MediaItem]. Tolérante aux champs absents :
/// un serveur ne renvoie que les `Fields` demandés.
abstract final class MediaMapper {
  static MediaItem fromDto(BaseItemDto dto) {
    final blur = dto.imageBlurHashes;
    String? blurOf(Map<String, String?>? map, String? tag) => tag == null ? null : map?[tag];

    ImageRef? own(ImageKind kind, String apiKey, Map<String, String?>? blurs) {
      final tag = dto.imageTags?[apiKey];
      if (tag == null) return null;
      return ImageRef(itemId: dto.id, type: kind, tag: tag, blurHash: blurOf(blurs, tag));
    }

    final backdrops = <ImageRef>[
      for (final (i, tag) in (dto.backdropImageTags ?? const <String>[]).indexed)
        ImageRef(itemId: dto.id, type: ImageKind.backdrop, tag: tag, index: i, blurHash: blurOf(blur?.backdrop, tag)),
    ];

    final parentBackdropTag = dto.parentBackdropImageTags?.firstOrNull;
    final parentBackdrop = dto.parentBackdropItemId != null && parentBackdropTag != null
        ? ImageRef(
            itemId: dto.parentBackdropItemId!,
            type: ImageKind.backdrop,
            tag: parentBackdropTag,
            blurHash: blurOf(blur?.backdrop, parentBackdropTag),
          )
        : null;

    final logo = own(ImageKind.logo, 'Logo', blur?.logo) ??
        (dto.parentLogoItemId != null && dto.parentLogoImageTag != null
            ? ImageRef(
                itemId: dto.parentLogoItemId!,
                type: ImageKind.logo,
                tag: dto.parentLogoImageTag!,
                blurHash: blurOf(blur?.logo, dto.parentLogoImageTag),
              )
            : null);

    final parentThumb = dto.parentThumbItemId != null && dto.parentThumbImageTag != null
        ? ImageRef(
            itemId: dto.parentThumbItemId!,
            type: ImageKind.thumb,
            tag: dto.parentThumbImageTag!,
            blurHash: blurOf(blur?.thumb, dto.parentThumbImageTag),
          )
        : (dto.seriesId != null && dto.seriesThumbImageTag != null
            ? ImageRef(itemId: dto.seriesId!, type: ImageKind.thumb, tag: dto.seriesThumbImageTag!)
            : null);

    final seriesPrimary = dto.seriesId != null && dto.seriesPrimaryImageTag != null
        ? ImageRef(
            itemId: dto.seriesId!,
            type: ImageKind.primary,
            tag: dto.seriesPrimaryImageTag!,
            blurHash: blurOf(blur?.primary, dto.seriesPrimaryImageTag),
          )
        : null;

    final ud = dto.userData;
    return MediaItem(
      id: dto.id,
      name: dto.name ?? '',
      kind: kindOf(dto.type),
      originalTitle: dto.originalTitle,
      overview: _clean(dto.overview),
      tagline: dto.taglines?.firstOrNull,
      year: dto.productionYear,
      premiereDate: dto.premiereDate,
      endDate: dto.endDate,
      status: dto.status,
      runTimeTicks: dto.runTimeTicks ?? dto.cumulativeRunTimeTicks,
      communityRating: dto.communityRating,
      criticRating: dto.criticRating,
      officialRating: dto.officialRating,
      genres: [
        for (final g in dto.genreItems ?? const <NameGuidPair>[])
          if (g.id != null && g.name != null) NamedRef(id: g.id!, name: g.name!),
      ],
      studios: [
        for (final s in dto.studios ?? const <NameGuidPair>[])
          if (s.id != null && s.name != null) NamedRef(id: s.id!, name: s.name!),
      ],
      people: [
        for (final p in dto.people ?? const <BaseItemPerson>[])
          PersonCredit(
            id: p.id,
            name: p.name ?? '',
            role: (p.role?.isEmpty ?? true) ? null : p.role,
            kind: _personKind(p.type),
            image: p.primaryImageTag == null
                ? null
                : ImageRef(
                    itemId: p.id,
                    type: ImageKind.primary,
                    tag: p.primaryImageTag!,
                    blurHash: p.imageBlurHashes?.primary?[p.primaryImageTag],
                  ),
          ),
      ],
      trailers: [
        for (final t in dto.remoteTrailers ?? const <MediaUrl>[])
          if (t.url != null && Uri.tryParse(t.url!)?.hasScheme == true) Trailer(url: Uri.parse(t.url!), name: t.name),
      ],
      localTrailerCount: dto.localTrailerCount ?? 0,
      user: UserState(
        played: ud?.played ?? false,
        favorite: ud?.isFavorite ?? false,
        positionTicks: ud?.playbackPositionTicks ?? 0,
        playedPercentage: ud?.playedPercentage,
        unplayedCount: ud?.unplayedItemCount,
      ),
      seriesId: dto.seriesId,
      seriesName: dto.seriesName,
      seasonId: dto.seasonId,
      seasonName: dto.seasonName,
      indexNumber: dto.indexNumber,
      parentIndexNumber: dto.parentIndexNumber,
      childCount: dto.childCount ?? dto.recursiveItemCount,
      libraryType: libraryTypeOf(dto.collectionType),
      streams: _streams(dto),
      primary: own(ImageKind.primary, 'Primary', blur?.primary),
      backdrops: backdrops,
      logo: logo,
      thumb: own(ImageKind.thumb, 'Thumb', blur?.thumb),
      parentBackdrop: parentBackdrop,
      parentThumb: parentThumb,
      seriesPrimary: seriesPrimary,
      primaryAspectRatio: dto.primaryImageAspectRatio,
      isFolder: dto.isFolder ?? false,
    );
  }

  static MediaKind kindOf(BaseItemDtoType? type) => switch (type) {
        BaseItemDtoType.movie => MediaKind.movie,
        BaseItemDtoType.series => MediaKind.series,
        BaseItemDtoType.season => MediaKind.season,
        BaseItemDtoType.episode => MediaKind.episode,
        BaseItemDtoType.boxSet => MediaKind.boxSet,
        BaseItemDtoType.folder || BaseItemDtoType.aggregateFolder => MediaKind.folder,
        BaseItemDtoType.collectionFolder || BaseItemDtoType.userView => MediaKind.collectionFolder,
        BaseItemDtoType.person => MediaKind.person,
        BaseItemDtoType.musicAlbum => MediaKind.musicAlbum,
        BaseItemDtoType.musicArtist => MediaKind.musicArtist,
        BaseItemDtoType.audio || BaseItemDtoType.audioBook => MediaKind.audio,
        BaseItemDtoType.playlist => MediaKind.playlist,
        BaseItemDtoType.video => MediaKind.video,
        BaseItemDtoType.musicVideo => MediaKind.musicVideo,
        BaseItemDtoType.photo => MediaKind.photo,
        BaseItemDtoType.photoAlbum => MediaKind.photoAlbum,
        BaseItemDtoType.trailer => MediaKind.trailer,
        BaseItemDtoType.tvChannel || BaseItemDtoType.liveTvChannel => MediaKind.tvChannel,
        _ => MediaKind.other,
      };

  static LibraryType? libraryTypeOf(BaseItemDtoCollectionType? type) => switch (type) {
        null => null,
        BaseItemDtoCollectionType.movies => LibraryType.movies,
        BaseItemDtoCollectionType.tvshows => LibraryType.tvshows,
        BaseItemDtoCollectionType.music => LibraryType.music,
        BaseItemDtoCollectionType.musicvideos => LibraryType.musicvideos,
        BaseItemDtoCollectionType.homevideos => LibraryType.homevideos,
        BaseItemDtoCollectionType.boxsets => LibraryType.boxsets,
        BaseItemDtoCollectionType.books => LibraryType.books,
        BaseItemDtoCollectionType.photos => LibraryType.photos,
        BaseItemDtoCollectionType.livetv => LibraryType.livetv,
        BaseItemDtoCollectionType.playlists => LibraryType.playlists,
        BaseItemDtoCollectionType.folders => LibraryType.folders,
        _ => LibraryType.unknown,
      };

  static PersonKind _personKind(BaseItemPersonType? t) => switch (t) {
        BaseItemPersonType.actor => PersonKind.actor,
        BaseItemPersonType.guestStar => PersonKind.guestStar,
        BaseItemPersonType.director => PersonKind.director,
        BaseItemPersonType.writer => PersonKind.writer,
        BaseItemPersonType.producer => PersonKind.producer,
        BaseItemPersonType.composer => PersonKind.composer,
        _ => PersonKind.other,
      };

  /// Flux de la première source (ou de l'élément si MediaSources n'est pas demandé).
  static List<StreamSummary> _streams(BaseItemDto dto) {
    final streams = dto.mediaSources?.firstOrNull?.mediaStreams ?? dto.mediaStreams ?? const <MediaStream>[];
    return [
      for (final s in streams)
        if (s.type == MediaStreamType.video)
          StreamSummary.video(
            codec: (s.codec ?? '').toLowerCase(),
            width: s.width,
            height: s.height,
            bitDepth: s.bitDepth,
            videoRange: videoRangeOf(s.videoRangeType),
          )
        else if (s.type == MediaStreamType.audio)
          StreamSummary.audio(
            codec: (s.codec ?? '').toLowerCase(),
            profile: s.profile,
            channels: s.channels,
            language: s.language,
            title: s.displayTitle,
            spatial: switch (s.audioSpatialFormat) {
              MediaStreamAudioSpatialFormat.dolbyAtmos => SpatialAudio.atmos,
              MediaStreamAudioSpatialFormat.dtsx => SpatialAudio.dtsX,
              _ => SpatialAudio.none,
            },
          ),
    ];
  }

  static VideoRange videoRangeOf(MediaStreamVideoRangeType? t) => switch (t) {
        MediaStreamVideoRangeType.dovi ||
        MediaStreamVideoRangeType.doviWithHdr10 ||
        MediaStreamVideoRangeType.doviWithHlg ||
        MediaStreamVideoRangeType.doviWithSdr ||
        MediaStreamVideoRangeType.doviWithEl ||
        MediaStreamVideoRangeType.doviWithHdr10Plus ||
        MediaStreamVideoRangeType.doviWithElhdr10Plus =>
          VideoRange.dolbyVision,
        MediaStreamVideoRangeType.hdr10Plus => VideoRange.hdr10Plus,
        MediaStreamVideoRangeType.hdr10 => VideoRange.hdr10,
        MediaStreamVideoRangeType.hlg => VideoRange.hlg,
        _ => VideoRange.sdr,
      };

  /// Retire les balises HTML parfois présentes dans les synopsis.
  static String? _clean(String? text) {
    if (text == null) return null;
    final cleaned = text
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
    return cleaned.isEmpty ? null : cleaned;
  }
}
