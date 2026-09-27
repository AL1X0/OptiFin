// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'base_item_dto.dart';
import 'base_item_dto_audio.dart';
import 'base_item_dto_channel_type.dart';
import 'base_item_dto_collection_type.dart';
import 'base_item_dto_extra_type.dart';
import 'base_item_dto_image_orientation.dart';
import 'base_item_dto_iso_type.dart';
import 'base_item_dto_location_type.dart';
import 'base_item_dto_media_type.dart';
import 'base_item_dto_play_access.dart';
import 'base_item_dto_type.dart';
import 'base_item_dto_video3_d_format.dart';
import 'base_item_dto_video_type.dart';
import 'base_item_person.dart';
import 'chapter_info.dart';
import 'day_of_week.dart';
import 'external_url.dart';
import 'image_blur_hashes.dart';
import 'media_source_info.dart';
import 'media_stream.dart';
import 'media_url.dart';
import 'metadata_field.dart';
import 'name_guid_pair.dart';
import 'trickplay_info_dto.dart';
import 'user_item_data_dto.dart';

part 'base_item_dto.g.dart';

/// This is strictly used as a data transfer object from the api layer.
/// This holds information about a BaseItem in a format that is convenient for the client.
@JsonSerializable()
class BaseItemDto {
  const BaseItemDto({
    required this.isFolder,
    required this.originalTitle,
    required this.serverId,
    required this.id,
    required this.etag,
    required this.sourceType,
    required this.playlistItemId,
    required this.dateCreated,
    required this.dateLastMediaAdded,
    required this.extraType,
    required this.airsBeforeSeasonNumber,
    required this.airsAfterSeasonNumber,
    required this.airsBeforeEpisodeNumber,
    required this.canDelete,
    required this.canDownload,
    required this.hasLyrics,
    required this.hasSubtitles,
    required this.preferredMetadataLanguage,
    required this.preferredMetadataCountryCode,
    required this.container,
    required this.sortName,
    required this.forcedSortName,
    required this.video3DFormat,
    required this.premiereDate,
    required this.externalUrls,
    required this.mediaSources,
    required this.criticRating,
    required this.productionLocations,
    required this.path,
    required this.enableMediaSourceDisplay,
    required this.officialRating,
    required this.customRating,
    required this.channelId,
    required this.channelName,
    required this.overview,
    required this.taglines,
    required this.genres,
    required this.communityRating,
    required this.cumulativeRunTimeTicks,
    required this.runTimeTicks,
    required this.playAccess,
    required this.aspectRatio,
    required this.productionYear,
    required this.isPlaceHolder,
    required this.number,
    required this.channelNumber,
    required this.indexNumber,
    required this.indexNumberEnd,
    required this.parentIndexNumber,
    required this.remoteTrailers,
    required this.providerIds,
    required this.isHd,
    required this.name,
    required this.parentId,
    required this.type,
    required this.people,
    required this.studios,
    required this.genreItems,
    required this.parentLogoItemId,
    required this.parentBackdropItemId,
    required this.parentBackdropImageTags,
    required this.localTrailerCount,
    required this.userData,
    required this.recursiveItemCount,
    required this.childCount,
    required this.seriesName,
    required this.seriesId,
    required this.seasonId,
    required this.specialFeatureCount,
    required this.displayPreferencesId,
    required this.status,
    required this.airTime,
    required this.airDays,
    required this.tags,
    required this.primaryImageAspectRatio,
    required this.artists,
    required this.artistItems,
    required this.album,
    required this.collectionType,
    required this.displayOrder,
    required this.albumId,
    required this.albumPrimaryImageTag,
    required this.seriesPrimaryImageTag,
    required this.albumArtist,
    required this.albumArtists,
    required this.seasonName,
    required this.mediaStreams,
    required this.videoType,
    required this.partCount,
    required this.mediaSourceCount,
    required this.imageTags,
    required this.backdropImageTags,
    required this.screenshotImageTags,
    required this.parentLogoImageTag,
    required this.parentArtItemId,
    required this.parentArtImageTag,
    required this.seriesThumbImageTag,
    required this.imageBlurHashes,
    required this.seriesStudio,
    required this.parentThumbItemId,
    required this.parentThumbImageTag,
    required this.parentPrimaryImageItemId,
    required this.originalLanguage,
    required this.chapters,
    required this.trickplay,
    required this.locationType,
    required this.isoType,
    required this.mediaType,
    required this.endDate,
    required this.lockedFields,
    required this.trailerCount,
    required this.movieCount,
    required this.seriesCount,
    required this.programCount,
    required this.episodeCount,
    required this.songCount,
    required this.albumCount,
    required this.artistCount,
    required this.musicVideoCount,
    required this.lockData,
    required this.width,
    required this.height,
    required this.cameraMake,
    required this.cameraModel,
    required this.software,
    required this.exposureTime,
    required this.focalLength,
    required this.imageOrientation,
    required this.aperture,
    required this.shutterSpeed,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.isoSpeedRating,
    required this.seriesTimerId,
    required this.programId,
    required this.channelPrimaryImageTag,
    required this.startDate,
    required this.completionPercentage,
    required this.isRepeat,
    required this.episodeTitle,
    required this.channelType,
    required this.audio,
    required this.isMovie,
    required this.isSports,
    required this.isSeries,
    required this.isLive,
    required this.isNews,
    required this.isKids,
    required this.isPremiere,
    required this.timerId,
    required this.normalizationGain,
    required this.albumNormalizationGain,
    required this.currentProgram,
    required this.parentPrimaryImageTag,
  });
  
  factory BaseItemDto.fromJson(Map<String, Object?> json) => _$BaseItemDtoFromJson(json);
  
  /// Gets or sets the name.
  @JsonKey(name: 'Name')
  final String? name;
  @JsonKey(name: 'OriginalTitle')
  final String? originalTitle;

  /// Gets or sets the server identifier.
  @JsonKey(name: 'ServerId')
  final String? serverId;

  /// Gets or sets the id.
  @JsonKey(name: 'Id')
  final String id;

  /// Gets or sets the etag.
  @JsonKey(name: 'Etag')
  final String? etag;

  /// Gets or sets the type of the source.
  @JsonKey(name: 'SourceType')
  final String? sourceType;

  /// Gets or sets the playlist item identifier.
  @JsonKey(name: 'PlaylistItemId')
  final String? playlistItemId;

  /// Gets or sets the date created.
  @JsonKey(name: 'DateCreated')
  final DateTime? dateCreated;
  @JsonKey(name: 'DateLastMediaAdded')
  final DateTime? dateLastMediaAdded;
  @JsonKey(name: 'ExtraType')
  final BaseItemDtoExtraType? extraType;
  @JsonKey(name: 'AirsBeforeSeasonNumber')
  final int? airsBeforeSeasonNumber;
  @JsonKey(name: 'AirsAfterSeasonNumber')
  final int? airsAfterSeasonNumber;
  @JsonKey(name: 'AirsBeforeEpisodeNumber')
  final int? airsBeforeEpisodeNumber;
  @JsonKey(name: 'CanDelete')
  final bool? canDelete;
  @JsonKey(name: 'CanDownload')
  final bool? canDownload;
  @JsonKey(name: 'HasLyrics')
  final bool? hasLyrics;
  @JsonKey(name: 'HasSubtitles')
  final bool? hasSubtitles;
  @JsonKey(name: 'PreferredMetadataLanguage')
  final String? preferredMetadataLanguage;
  @JsonKey(name: 'PreferredMetadataCountryCode')
  final String? preferredMetadataCountryCode;
  @JsonKey(name: 'Container')
  final String? container;

  /// Gets or sets the name of the sort.
  @JsonKey(name: 'SortName')
  final String? sortName;
  @JsonKey(name: 'ForcedSortName')
  final String? forcedSortName;

  /// Gets or sets the video3 D format.
  @JsonKey(name: 'Video3DFormat')
  final BaseItemDtoVideo3DFormat? video3DFormat;

  /// Gets or sets the premiere date.
  @JsonKey(name: 'PremiereDate')
  final DateTime? premiereDate;

  /// Gets or sets the external urls.
  @JsonKey(name: 'ExternalUrls')
  final List<ExternalUrl>? externalUrls;

  /// Gets or sets the media versions.
  @JsonKey(name: 'MediaSources')
  final List<MediaSourceInfo>? mediaSources;

  /// Gets or sets the critic rating.
  @JsonKey(name: 'CriticRating')
  final double? criticRating;
  @JsonKey(name: 'ProductionLocations')
  final List<String>? productionLocations;

  /// Gets or sets the path.
  @JsonKey(name: 'Path')
  final String? path;
  @JsonKey(name: 'EnableMediaSourceDisplay')
  final bool? enableMediaSourceDisplay;

  /// Gets or sets the official rating.
  @JsonKey(name: 'OfficialRating')
  final String? officialRating;

  /// Gets or sets the custom rating.
  @JsonKey(name: 'CustomRating')
  final String? customRating;

  /// Gets or sets the channel identifier.
  @JsonKey(name: 'ChannelId')
  final String? channelId;
  @JsonKey(name: 'ChannelName')
  final String? channelName;

  /// Gets or sets the overview.
  @JsonKey(name: 'Overview')
  final String? overview;

  /// Gets or sets the taglines.
  @JsonKey(name: 'Taglines')
  final List<String>? taglines;

  /// Gets or sets the genres.
  @JsonKey(name: 'Genres')
  final List<String>? genres;

  /// Gets or sets the community rating.
  @JsonKey(name: 'CommunityRating')
  final double? communityRating;

  /// Gets or sets the cumulative run time ticks.
  @JsonKey(name: 'CumulativeRunTimeTicks')
  final int? cumulativeRunTimeTicks;

  /// Gets or sets the run time ticks.
  @JsonKey(name: 'RunTimeTicks')
  final int? runTimeTicks;

  /// Gets or sets the play access.
  @JsonKey(name: 'PlayAccess')
  final BaseItemDtoPlayAccess? playAccess;

  /// Gets or sets the aspect ratio.
  @JsonKey(name: 'AspectRatio')
  final String? aspectRatio;

  /// Gets or sets the production year.
  @JsonKey(name: 'ProductionYear')
  final int? productionYear;

  /// Gets or sets a value indicating whether this instance is place holder.
  @JsonKey(name: 'IsPlaceHolder')
  final bool? isPlaceHolder;

  /// Gets or sets the number.
  @JsonKey(name: 'Number')
  final String? number;
  @JsonKey(name: 'ChannelNumber')
  final String? channelNumber;

  /// Gets or sets the index number.
  @JsonKey(name: 'IndexNumber')
  final int? indexNumber;

  /// Gets or sets the index number end.
  @JsonKey(name: 'IndexNumberEnd')
  final int? indexNumberEnd;

  /// Gets or sets the parent index number.
  @JsonKey(name: 'ParentIndexNumber')
  final int? parentIndexNumber;

  /// Gets or sets the trailer urls.
  @JsonKey(name: 'RemoteTrailers')
  final List<MediaUrl>? remoteTrailers;

  /// Gets or sets the provider ids.
  @JsonKey(name: 'ProviderIds')
  final Map<String, String?>? providerIds;

  /// Gets or sets a value indicating whether this instance is HD.
  @JsonKey(name: 'IsHD')
  final bool? isHd;

  /// Gets or sets a value indicating whether this instance is folder.
  @JsonKey(name: 'IsFolder')
  final bool? isFolder;

  /// Gets or sets the parent id.
  @JsonKey(name: 'ParentId')
  final String? parentId;

  /// The base item kind.
  @JsonKey(name: 'Type')
  final BaseItemDtoType type;

  /// Gets or sets the people.
  @JsonKey(name: 'People')
  final List<BaseItemPerson>? people;

  /// Gets or sets the studios.
  @JsonKey(name: 'Studios')
  final List<NameGuidPair>? studios;
  @JsonKey(name: 'GenreItems')
  final List<NameGuidPair>? genreItems;

  /// Gets or sets whether the item has a logo, this will hold the Id of the Parent that has one.
  @JsonKey(name: 'ParentLogoItemId')
  final String? parentLogoItemId;

  /// Gets or sets whether the item has any backdrops, this will hold the Id of the Parent that has one.
  @JsonKey(name: 'ParentBackdropItemId')
  final String? parentBackdropItemId;

  /// Gets or sets the parent backdrop image tags.
  @JsonKey(name: 'ParentBackdropImageTags')
  final List<String>? parentBackdropImageTags;

  /// Gets or sets the local trailer count.
  @JsonKey(name: 'LocalTrailerCount')
  final int? localTrailerCount;

  /// Gets or sets the user data for this item based on the user it's being requested for.
  @JsonKey(name: 'UserData')
  final UserItemDataDto? userData;

  /// Gets or sets the recursive item count.
  @JsonKey(name: 'RecursiveItemCount')
  final int? recursiveItemCount;

  /// Gets or sets the child count.
  @JsonKey(name: 'ChildCount')
  final int? childCount;

  /// Gets or sets the name of the series.
  @JsonKey(name: 'SeriesName')
  final String? seriesName;

  /// Gets or sets the series id.
  @JsonKey(name: 'SeriesId')
  final String? seriesId;

  /// Gets or sets the season identifier.
  @JsonKey(name: 'SeasonId')
  final String? seasonId;

  /// Gets or sets the special feature count.
  @JsonKey(name: 'SpecialFeatureCount')
  final int? specialFeatureCount;

  /// Gets or sets the display preferences id.
  @JsonKey(name: 'DisplayPreferencesId')
  final String? displayPreferencesId;

  /// Gets or sets the status.
  @JsonKey(name: 'Status')
  final String? status;

  /// Gets or sets the air time.
  @JsonKey(name: 'AirTime')
  final String? airTime;

  /// Gets or sets the air days.
  @JsonKey(name: 'AirDays')
  final List<DayOfWeek>? airDays;

  /// Gets or sets the tags.
  @JsonKey(name: 'Tags')
  final List<String>? tags;

  /// Gets or sets the primary image aspect ratio, after image enhancements.
  @JsonKey(name: 'PrimaryImageAspectRatio')
  final double? primaryImageAspectRatio;

  /// Gets or sets the artists.
  @JsonKey(name: 'Artists')
  final List<String>? artists;

  /// Gets or sets the artist items.
  @JsonKey(name: 'ArtistItems')
  final List<NameGuidPair>? artistItems;

  /// Gets or sets the album.
  @JsonKey(name: 'Album')
  final String? album;

  /// Gets or sets the type of the collection.
  @JsonKey(name: 'CollectionType')
  final BaseItemDtoCollectionType? collectionType;

  /// Gets or sets the display order.
  @JsonKey(name: 'DisplayOrder')
  final String? displayOrder;

  /// Gets or sets the album id.
  @JsonKey(name: 'AlbumId')
  final String? albumId;

  /// Gets or sets the album image tag.
  @JsonKey(name: 'AlbumPrimaryImageTag')
  final String? albumPrimaryImageTag;

  /// Gets or sets the series primary image tag.
  @JsonKey(name: 'SeriesPrimaryImageTag')
  final String? seriesPrimaryImageTag;

  /// Gets or sets the album artist.
  @JsonKey(name: 'AlbumArtist')
  final String? albumArtist;

  /// Gets or sets the album artists.
  @JsonKey(name: 'AlbumArtists')
  final List<NameGuidPair>? albumArtists;

  /// Gets or sets the name of the season.
  @JsonKey(name: 'SeasonName')
  final String? seasonName;

  /// Gets or sets the media streams.
  @JsonKey(name: 'MediaStreams')
  final List<MediaStream>? mediaStreams;

  /// Gets or sets the type of the video.
  @JsonKey(name: 'VideoType')
  final BaseItemDtoVideoType? videoType;

  /// Gets or sets the part count.
  @JsonKey(name: 'PartCount')
  final int? partCount;
  @JsonKey(name: 'MediaSourceCount')
  final int? mediaSourceCount;

  /// Gets or sets the image tags.
  @JsonKey(name: 'ImageTags')
  final Map<String, String?>? imageTags;

  /// Gets or sets the backdrop image tags.
  @JsonKey(name: 'BackdropImageTags')
  final List<String>? backdropImageTags;

  /// Gets or sets the screenshot image tags.
  @JsonKey(name: 'ScreenshotImageTags')
  final List<String>? screenshotImageTags;

  /// Gets or sets the parent logo image tag.
  @JsonKey(name: 'ParentLogoImageTag')
  final String? parentLogoImageTag;

  /// Gets or sets whether the item has fan art, this will hold the Id of the Parent that has one.
  @JsonKey(name: 'ParentArtItemId')
  final String? parentArtItemId;

  /// Gets or sets the parent art image tag.
  @JsonKey(name: 'ParentArtImageTag')
  final String? parentArtImageTag;

  /// Gets or sets the series thumb image tag.
  @JsonKey(name: 'SeriesThumbImageTag')
  final String? seriesThumbImageTag;

  /// Gets or sets the blurhashes for the image tags.
  /// Maps image type to dictionary mapping image tag to blurhash value.
  @JsonKey(name: 'ImageBlurHashes')
  final ImageBlurHashes? imageBlurHashes;

  /// Gets or sets the series studio.
  @JsonKey(name: 'SeriesStudio')
  final String? seriesStudio;

  /// Gets or sets the parent thumb item id.
  @JsonKey(name: 'ParentThumbItemId')
  final String? parentThumbItemId;

  /// Gets or sets the parent thumb image tag.
  @JsonKey(name: 'ParentThumbImageTag')
  final String? parentThumbImageTag;

  /// Gets or sets the parent primary image item identifier.
  @JsonKey(name: 'ParentPrimaryImageItemId')
  final String? parentPrimaryImageItemId;

  /// Gets or sets the parent primary image tag.
  @JsonKey(name: 'ParentPrimaryImageTag')
  final String? parentPrimaryImageTag;

  /// Gets or sets the chapters.
  @JsonKey(name: 'Chapters')
  final List<ChapterInfo>? chapters;

  /// Gets or sets the trickplay manifest.
  @JsonKey(name: 'Trickplay')
  final Map<String, Map<String, TrickplayInfoDto>?>? trickplay;

  /// Gets or sets the type of the location.
  @JsonKey(name: 'LocationType')
  final BaseItemDtoLocationType? locationType;

  /// Gets or sets the type of the iso.
  @JsonKey(name: 'IsoType')
  final BaseItemDtoIsoType? isoType;

  /// Media types.
  @JsonKey(name: 'MediaType')
  final BaseItemDtoMediaType mediaType;

  /// Gets or sets the end date.
  @JsonKey(name: 'EndDate')
  final DateTime? endDate;

  /// Gets or sets the locked fields.
  @JsonKey(name: 'LockedFields')
  final List<MetadataField>? lockedFields;

  /// Gets or sets the trailer count.
  @JsonKey(name: 'TrailerCount')
  final int? trailerCount;

  /// Gets or sets the movie count.
  @JsonKey(name: 'MovieCount')
  final int? movieCount;

  /// Gets or sets the series count.
  @JsonKey(name: 'SeriesCount')
  final int? seriesCount;
  @JsonKey(name: 'ProgramCount')
  final int? programCount;

  /// Gets or sets the episode count.
  @JsonKey(name: 'EpisodeCount')
  final int? episodeCount;

  /// Gets or sets the song count.
  @JsonKey(name: 'SongCount')
  final int? songCount;

  /// Gets or sets the album count.
  @JsonKey(name: 'AlbumCount')
  final int? albumCount;
  @JsonKey(name: 'ArtistCount')
  final int? artistCount;

  /// Gets or sets the music video count.
  @JsonKey(name: 'MusicVideoCount')
  final int? musicVideoCount;

  /// Gets or sets a value indicating whether [enable internet providers].
  @JsonKey(name: 'LockData')
  final bool? lockData;
  @JsonKey(name: 'Width')
  final int? width;
  @JsonKey(name: 'Height')
  final int? height;
  @JsonKey(name: 'CameraMake')
  final String? cameraMake;
  @JsonKey(name: 'CameraModel')
  final String? cameraModel;
  @JsonKey(name: 'Software')
  final String? software;
  @JsonKey(name: 'ExposureTime')
  final double? exposureTime;
  @JsonKey(name: 'FocalLength')
  final double? focalLength;
  @JsonKey(name: 'ImageOrientation')
  final BaseItemDtoImageOrientation? imageOrientation;
  @JsonKey(name: 'Aperture')
  final double? aperture;
  @JsonKey(name: 'ShutterSpeed')
  final double? shutterSpeed;
  @JsonKey(name: 'Latitude')
  final double? latitude;
  @JsonKey(name: 'Longitude')
  final double? longitude;
  @JsonKey(name: 'Altitude')
  final double? altitude;
  @JsonKey(name: 'IsoSpeedRating')
  final int? isoSpeedRating;

  /// Gets or sets the series timer identifier.
  @JsonKey(name: 'SeriesTimerId')
  final String? seriesTimerId;

  /// Gets or sets the program identifier.
  @JsonKey(name: 'ProgramId')
  final String? programId;

  /// Gets or sets the channel primary image tag.
  @JsonKey(name: 'ChannelPrimaryImageTag')
  final String? channelPrimaryImageTag;

  /// Gets or sets the start date of the recording, in UTC.
  @JsonKey(name: 'StartDate')
  final DateTime? startDate;

  /// Gets or sets the completion percentage.
  @JsonKey(name: 'CompletionPercentage')
  final double? completionPercentage;

  /// Gets or sets a value indicating whether this instance is repeat.
  @JsonKey(name: 'IsRepeat')
  final bool? isRepeat;

  /// Gets or sets the episode title.
  @JsonKey(name: 'EpisodeTitle')
  final String? episodeTitle;

  /// Gets or sets the type of the channel.
  @JsonKey(name: 'ChannelType')
  final BaseItemDtoChannelType? channelType;

  /// Gets or sets the audio.
  @JsonKey(name: 'Audio')
  final BaseItemDtoAudio? audio;

  /// Gets or sets a value indicating whether this instance is movie.
  @JsonKey(name: 'IsMovie')
  final bool? isMovie;

  /// Gets or sets a value indicating whether this instance is sports.
  @JsonKey(name: 'IsSports')
  final bool? isSports;

  /// Gets or sets a value indicating whether this instance is series.
  @JsonKey(name: 'IsSeries')
  final bool? isSeries;

  /// Gets or sets a value indicating whether this instance is live.
  @JsonKey(name: 'IsLive')
  final bool? isLive;

  /// Gets or sets a value indicating whether this instance is news.
  @JsonKey(name: 'IsNews')
  final bool? isNews;

  /// Gets or sets a value indicating whether this instance is kids.
  @JsonKey(name: 'IsKids')
  final bool? isKids;

  /// Gets or sets a value indicating whether this instance is premiere.
  @JsonKey(name: 'IsPremiere')
  final bool? isPremiere;

  /// Gets or sets the timer identifier.
  @JsonKey(name: 'TimerId')
  final String? timerId;

  /// Gets or sets the gain required for audio normalization.
  @JsonKey(name: 'NormalizationGain')
  final double? normalizationGain;

  /// Gets or sets the gain required for audio normalization. This field is inherited from music album normalization gain.
  @JsonKey(name: 'AlbumNormalizationGain')
  final double? albumNormalizationGain;

  /// Gets or sets the current program.
  @JsonKey(name: 'CurrentProgram')
  final BaseItemDto? currentProgram;
  @JsonKey(name: 'OriginalLanguage')
  final String? originalLanguage;

  Map<String, Object?> toJson() => _$BaseItemDtoToJson(this);
}
