/// Modèle de domaine d'un élément Jellyfin, découplé des DTO générés.
///
/// Ne contient que ce que l'UI affiche : les écrans ne manipulent jamais `BaseItemDto`.
library;

enum MediaKind {
  movie,
  series,
  season,
  episode,
  boxSet,
  folder,
  collectionFolder,
  person,
  musicAlbum,
  musicArtist,
  audio,
  playlist,
  video,
  musicVideo,
  photo,
  photoAlbum,
  trailer,
  tvChannel,
  other;

  /// Contenu vidéo lisible directement (bouton Lecture).
  bool get isPlayableVideo =>
      this == movie || this == episode || this == video || this == musicVideo || this == trailer;

  /// Affiché en format affiche 2:3 plutôt que paysage.
  bool get prefersPoster =>
      this == movie || this == series || this == season || this == boxSet || this == person || this == playlist;
}

/// Type de bibliothèque (CollectionType Jellyfin).
enum LibraryType {
  movies,
  tvshows,
  music,
  musicvideos,
  homevideos,
  boxsets,
  books,
  photos,
  livetv,
  playlists,
  folders,
  unknown,
}

/// Référence d'image : quel élément, quel type, quel tag de cache, quel BlurHash.
class ImageRef {
  const ImageRef({required this.itemId, required this.type, required this.tag, this.blurHash, this.index = 0});

  final String itemId;
  final ImageKind type;
  final String tag;
  final String? blurHash;
  final int index;

  @override
  bool operator ==(Object other) =>
      other is ImageRef && other.itemId == itemId && other.type == type && other.tag == tag && other.index == index;

  @override
  int get hashCode => Object.hash(itemId, type, tag, index);

  @override
  String toString() => 'ImageRef($itemId/$type/$index#$tag)';
}

enum ImageKind { primary, backdrop, logo, thumb, banner, art }

class UserState {
  const UserState({
    this.played = false,
    this.favorite = false,
    this.positionTicks = 0,
    this.playedPercentage,
    this.unplayedCount,
  });

  final bool played;
  final bool favorite;
  final int positionTicks;
  final double? playedPercentage;
  final int? unplayedCount;

  /// Progression 0..1 si une lecture est en cours.
  double? get progress {
    final p = playedPercentage;
    if (p == null || p <= 0 || p >= 100) return null;
    return p / 100;
  }

  UserState copyWith({bool? played, bool? favorite}) => UserState(
    played: played ?? this.played,
    favorite: favorite ?? this.favorite,
    positionTicks: played == true ? 0 : positionTicks,
    playedPercentage: played == true ? null : playedPercentage,
    unplayedCount: played == true ? 0 : unplayedCount,
  );
}

class PersonCredit {
  const PersonCredit({required this.id, required this.name, this.role, required this.kind, this.image});

  final String id;
  final String name;
  final String? role;
  final PersonKind kind;
  final ImageRef? image;
}

enum PersonKind { actor, guestStar, director, writer, producer, composer, other }

class NamedRef {
  const NamedRef({required this.id, required this.name});

  final String id;
  final String name;
}

class Trailer {
  const Trailer({required this.url, this.name});

  final Uri url;
  final String? name;
}

/// Résumé technique d'un flux, suffisant pour les badges (le moteur de lecture
/// travaillera sur les MediaSources complètes en phase 3/4).
class StreamSummary {
  const StreamSummary.video({
    required this.codec,
    this.width,
    this.height,
    this.videoRange = VideoRange.sdr,
    this.bitDepth,
  }) : isVideo = true,
       profile = null,
       channels = null,
       spatial = SpatialAudio.none,
       language = null,
       title = null;

  const StreamSummary.audio({
    required this.codec,
    this.profile,
    this.channels,
    this.spatial = SpatialAudio.none,
    this.language,
    this.title,
  }) : isVideo = false,
       width = null,
       height = null,
       videoRange = VideoRange.sdr,
       bitDepth = null;

  final bool isVideo;
  final String codec;
  final int? width;
  final int? height;
  final VideoRange videoRange;
  final int? bitDepth;
  final String? profile;
  final int? channels;
  final SpatialAudio spatial;
  final String? language;
  final String? title;
}

enum VideoRange { sdr, hlg, hdr10, hdr10Plus, dolbyVision }

enum SpatialAudio { none, atmos, dtsX }

class MediaItem {
  const MediaItem({
    required this.id,
    required this.name,
    required this.kind,
    this.originalTitle,
    this.overview,
    this.tagline,
    this.year,
    this.premiereDate,
    this.endDate,
    this.status,
    this.runTimeTicks,
    this.communityRating,
    this.criticRating,
    this.officialRating,
    this.genres = const [],
    this.studios = const [],
    this.people = const [],
    this.trailers = const [],
    this.localTrailerCount = 0,
    this.user = const UserState(),
    this.seriesId,
    this.seriesName,
    this.seasonId,
    this.seasonName,
    this.indexNumber,
    this.parentIndexNumber,
    this.childCount,
    this.libraryType,
    this.streams = const [],
    this.primary,
    this.backdrops = const [],
    this.logo,
    this.thumb,
    this.parentBackdrop,
    this.parentThumb,
    this.seriesPrimary,
    this.primaryAspectRatio,
    this.isFolder = false,
  });

  final String id;
  final String name;
  final MediaKind kind;
  final String? originalTitle;
  final String? overview;
  final String? tagline;
  final int? year;
  final DateTime? premiereDate;
  final DateTime? endDate;
  final String? status;
  final int? runTimeTicks;
  final double? communityRating;
  final double? criticRating;
  final String? officialRating;
  final List<NamedRef> genres;
  final List<NamedRef> studios;
  final List<PersonCredit> people;
  final List<Trailer> trailers;
  final int localTrailerCount;
  final UserState user;
  final String? seriesId;
  final String? seriesName;
  final String? seasonId;
  final String? seasonName;
  final int? indexNumber;
  final int? parentIndexNumber;
  final int? childCount;
  final LibraryType? libraryType;
  final List<StreamSummary> streams;

  final ImageRef? primary;
  final List<ImageRef> backdrops;

  /// Logo propre ou hérité (série pour un épisode).
  final ImageRef? logo;
  final ImageRef? thumb;
  final ImageRef? parentBackdrop;
  final ImageRef? parentThumb;
  final ImageRef? seriesPrimary;
  final double? primaryAspectRatio;
  final bool isFolder;

  Duration? get runtime => runTimeTicks == null ? null : Duration(microseconds: runTimeTicks! ~/ 10);
  Duration get resumePosition => Duration(microseconds: user.positionTicks ~/ 10);

  /// Image de fond immersive : backdrop propre, sinon hérité, sinon vignette.
  ImageRef? get backdrop => backdrops.firstOrNull ?? parentBackdrop ?? thumb ?? parentThumb;

  /// Image 16:9 pour les cartes paysage.
  ImageRef? get landscape => switch (kind) {
    MediaKind.episode || MediaKind.video || MediaKind.musicVideo => primary ?? parentThumb ?? parentBackdrop,
    _ => thumb ?? backdrops.firstOrNull ?? parentThumb ?? parentBackdrop ?? primary,
  };

  /// Image 2:3 pour les cartes affiche (épisode → affiche de la série).
  ImageRef? get poster => kind == MediaKind.episode ? (seriesPrimary ?? primary) : primary;

  /// « S1 · É3 » pour un épisode.
  String? get episodeLabel {
    if (kind != MediaKind.episode) return null;
    final s = parentIndexNumber;
    final e = indexNumber;
    if (s == null && e == null) return null;
    if (s == 0) return 'Spécial${e != null ? ' $e' : ''}';
    return [if (s != null) 'S$s', if (e != null) 'É$e'].join(' · ');
  }

  MediaItem withUser(UserState user) => MediaItem(
    id: id,
    name: name,
    kind: kind,
    originalTitle: originalTitle,
    overview: overview,
    tagline: tagline,
    year: year,
    premiereDate: premiereDate,
    endDate: endDate,
    status: status,
    runTimeTicks: runTimeTicks,
    communityRating: communityRating,
    criticRating: criticRating,
    officialRating: officialRating,
    genres: genres,
    studios: studios,
    people: people,
    trailers: trailers,
    localTrailerCount: localTrailerCount,
    user: user,
    seriesId: seriesId,
    seriesName: seriesName,
    seasonId: seasonId,
    seasonName: seasonName,
    indexNumber: indexNumber,
    parentIndexNumber: parentIndexNumber,
    childCount: childCount,
    libraryType: libraryType,
    streams: streams,
    primary: primary,
    backdrops: backdrops,
    logo: logo,
    thumb: thumb,
    parentBackdrop: parentBackdrop,
    parentThumb: parentThumb,
    seriesPrimary: seriesPrimary,
    primaryAspectRatio: primaryAspectRatio,
    isFolder: isFolder,
  );
}
