// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/all_theme_media_result.dart';
import '../models/base_item_dto.dart';
import '../models/base_item_dto_query_result.dart';
import '../models/base_item_kind.dart';
import '../models/image_refresh_mode.dart';
import '../models/image_type.dart';
import '../models/item_counts.dart';
import '../models/item_fields.dart';
import '../models/item_filter.dart';
import '../models/item_sort_by.dart';
import '../models/library_content_type.dart';
import '../models/library_options_result_dto.dart';
import '../models/location_type.dart';
import '../models/media_type.dart';
import '../models/media_update_info_dto.dart';
import '../models/metadata_refresh_mode.dart';
import '../models/series_status.dart';
import '../models/sort_order.dart';
import '../models/theme_media_result.dart';
import '../models/video_type.dart';

part 'library_client.g.dart';

@RestApi()
abstract class LibraryClient {
  factory LibraryClient(Dio dio, {String? baseUrl}) = _LibraryClient;

  /// Refreshes metadata for an item.
  ///
  /// [itemId] - Item id.
  ///
  /// [metadataRefreshMode] - (Optional) Specifies the metadata refresh mode.
  ///
  /// [imageRefreshMode] - (Optional) Specifies the image refresh mode.
  ///
  /// [replaceAllMetadata] - (Optional) Determines if metadata should be replaced. Only applicable if mode is FullRefresh.
  ///
  /// [replaceAllImages] - (Optional) Determines if images should be replaced. Only applicable if mode is FullRefresh.
  ///
  /// [regenerateTrickplay] - (Optional) Determines if trickplay images should be replaced. Only applicable if mode is FullRefresh.
  @POST('/Items/{itemId}/Refresh')
  Future<void> refreshItem({
    @Path('itemId') required String itemId,
    @Query('replaceAllMetadata') bool? replaceAllMetadata = false,
    @Query('replaceAllImages') bool? replaceAllImages = false,
    @Query('regenerateTrickplay') bool? regenerateTrickplay = false,
    @Query('metadataRefreshMode') MetadataRefreshMode? metadataRefreshMode,
    @Query('imageRefreshMode') ImageRefreshMode? imageRefreshMode,
  });

  /// Gets items based on a query.
  ///
  /// [userId] - The user id supplied as query parameter; this is required when not using an API key.
  ///
  /// [maxOfficialRating] - Optional filter by maximum official rating (PG, PG-13, TV-MA, etc).
  ///
  /// [hasThemeSong] - Optional filter by items with theme songs.
  ///
  /// [hasThemeVideo] - Optional filter by items with theme videos.
  ///
  /// [hasSubtitles] - Optional filter by items with subtitles.
  ///
  /// [hasSpecialFeature] - Optional filter by items with special features.
  ///
  /// [hasTrailer] - Optional filter by items with trailers.
  ///
  /// [adjacentTo] - Optional. Return items that are siblings of a supplied item.
  ///
  /// [indexNumber] - Optional filter by index number.
  ///
  /// [parentIndexNumber] - Optional filter by parent index number.
  ///
  /// [hasParentalRating] - Optional filter by items that have or do not have a parental rating.
  ///
  /// [isHd] - Optional filter by items that are HD or not.
  ///
  /// [is4K] - Optional filter by items that are 4K or not.
  ///
  /// [locationTypes] - Optional. If specified, results will be filtered based on LocationType. This allows multiple, comma delimited.
  ///
  /// [excludeLocationTypes] - Optional. If specified, results will be filtered based on the LocationType. This allows multiple, comma delimited.
  ///
  /// [isMissing] - Optional filter by items that are missing episodes or not.
  ///
  /// [isUnaired] - Optional filter by items that are unaired episodes or not.
  ///
  /// [minCommunityRating] - Optional filter by minimum community rating.
  ///
  /// [minCriticRating] - Optional filter by minimum critic rating.
  ///
  /// [minPremiereDate] - Optional. The minimum premiere date. Format = ISO.
  ///
  /// [minDateLastSaved] - Optional. The minimum last saved date. Format = ISO.
  ///
  /// [minDateLastSavedForUser] - Optional. The minimum last saved date for the current user. Format = ISO.
  ///
  /// [maxPremiereDate] - Optional. The maximum premiere date. Format = ISO.
  ///
  /// [hasOverview] - Optional filter by items that have an overview or not.
  ///
  /// [hasImdbId] - Optional filter by items that have an IMDb id or not.
  ///
  /// [hasTmdbId] - Optional filter by items that have a TMDb id or not.
  ///
  /// [hasTvdbId] - Optional filter by items that have a TVDb id or not.
  ///
  /// [isMovie] - Optional filter for live tv movies.
  ///
  /// [isSeries] - Optional filter for live tv series.
  ///
  /// [isNews] - Optional filter for live tv news.
  ///
  /// [isKids] - Optional filter for live tv kids.
  ///
  /// [isSports] - Optional filter for live tv sports.
  ///
  /// [excludeItemIds] - Optional. If specified, results will be filtered by excluding item ids. This allows multiple, comma delimited.
  ///
  /// [startIndex] - Optional. The record index to start at. All items with a lower index will be dropped from the results.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [recursive] - When searching within folders, this determines whether or not the search will be recursive. true/false.
  ///
  /// [searchTerm] - Optional. Filter based on a search term.
  ///
  /// [sortOrder] - Sort Order - Ascending, Descending.
  ///
  /// [parentId] - Specify this to localize the search to a specific item or folder. Omit to use the root.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output. This allows multiple, comma delimited. Options: Budget, Chapters, DateCreated, Genres, HomePageUrl, IndexOptions, MediaStreams, Overview, ParentId, Path, People, ProviderIds, PrimaryImageAspectRatio, Revenue, SortName, Studios, Taglines.
  ///
  /// [excludeItemTypes] - Optional. If specified, results will be filtered based on item type. This allows multiple, comma delimited.
  ///
  /// [includeItemTypes] - Optional. If specified, results will be filtered based on the item type. This allows multiple, comma delimited.
  ///
  /// [filters] - Optional. Specify additional filters to apply. This allows multiple, comma delimited. Options: IsFolder, IsNotFolder, IsUnplayed, IsPlayed, IsFavorite, IsResumable, Likes, Dislikes.
  ///
  /// [isFavorite] - Optional filter by items that are marked as favorite, or not.
  ///
  /// [mediaTypes] - Optional filter by MediaType. Allows multiple, comma delimited.
  ///
  /// [imageTypes] - Optional. If specified, results will be filtered based on those containing image types. This allows multiple, comma delimited.
  ///
  /// [sortBy] - Optional. Specify one or more sort orders, comma delimited. Options: Album, AlbumArtist, Artist, Budget, CommunityRating, CriticRating, DateCreated, DatePlayed, PlayCount, PremiereDate, ProductionYear, SortName, Random, Revenue, Runtime.
  ///
  /// [isPlayed] - Optional filter by items that are played, or not.
  ///
  /// [genres] - Optional. If specified, results will be filtered based on genre. This allows multiple, pipe delimited.
  ///
  /// [officialRatings] - Optional. If specified, results will be filtered based on OfficialRating. This allows multiple, pipe delimited.
  ///
  /// [tags] - Optional. If specified, results will be filtered based on tag. This allows multiple, pipe delimited.
  ///
  /// [years] - Optional. If specified, results will be filtered based on production year. This allows multiple, comma delimited.
  ///
  /// [enableUserData] - Optional, include user data.
  ///
  /// [imageTypeLimit] - Optional, the max number of images to return, per image type.
  ///
  /// [enableImageTypes] - Optional. The image types to include in the output.
  ///
  /// [person] - Optional. If specified, results will be filtered to include only those containing the specified person.
  ///
  /// [personIds] - Optional. If specified, results will be filtered to include only those containing the specified person id.
  ///
  /// [personTypes] - Optional. If specified, along with Person, results will be filtered to include only those containing the specified person and PersonType. Allows multiple, comma-delimited.
  ///
  /// [studios] - Optional. If specified, results will be filtered based on studio. This allows multiple, pipe delimited.
  ///
  /// [artists] - Optional. If specified, results will be filtered based on artists. This allows multiple, pipe delimited.
  ///
  /// [excludeArtistIds] - Optional. If specified, results will be filtered based on artist id. This allows multiple, pipe delimited.
  ///
  /// [artistIds] - Optional. If specified, results will be filtered to include only those containing the specified artist id.
  ///
  /// [albumArtistIds] - Optional. If specified, results will be filtered to include only those containing the specified album artist id.
  ///
  /// [contributingArtistIds] - Optional. If specified, results will be filtered to include only those containing the specified contributing artist id.
  ///
  /// [albums] - Optional. If specified, results will be filtered based on album. This allows multiple, pipe delimited.
  ///
  /// [albumIds] - Optional. If specified, results will be filtered based on album id. This allows multiple, pipe delimited.
  ///
  /// [ids] - Optional. If specific items are needed, specify a list of item id's to retrieve. This allows multiple, comma delimited.
  ///
  /// [videoTypes] - Optional filter by VideoType (videofile, dvd, bluray, iso). Allows multiple, comma delimited.
  ///
  /// [minOfficialRating] - Optional filter by minimum official rating (PG, PG-13, TV-MA, etc).
  ///
  /// [isLocked] - Optional filter by items that are locked.
  ///
  /// [isPlaceHolder] - Optional filter by items that are placeholders.
  ///
  /// [hasOfficialRating] - Optional filter by items that have official ratings.
  ///
  /// [collapseBoxSetItems] - Whether or not to hide items behind their boxsets.
  ///
  /// [minWidth] - Optional. Filter by the minimum width of the item.
  ///
  /// [minHeight] - Optional. Filter by the minimum height of the item.
  ///
  /// [maxWidth] - Optional. Filter by the maximum width of the item.
  ///
  /// [maxHeight] - Optional. Filter by the maximum height of the item.
  ///
  /// [is3D] - Optional filter by items that are 3D, or not.
  ///
  /// [seriesStatus] - Optional filter by Series Status. Allows multiple, comma delimited.
  ///
  /// [nameStartsWithOrGreater] - Optional filter by items whose name is sorted equally or greater than a given input string.
  ///
  /// [nameStartsWith] - Optional filter by items whose name is sorted equally than a given input string.
  ///
  /// [nameLessThan] - Optional filter by items whose name is equally or lesser than a given input string.
  ///
  /// [studioIds] - Optional. If specified, results will be filtered based on studio id. This allows multiple, pipe delimited.
  ///
  /// [genreIds] - Optional. If specified, results will be filtered based on genre id. This allows multiple, pipe delimited.
  ///
  /// [audioLanguages] - Optional. If specified, results will be filtered based on audio language. This allows multiple, comma delimited values.
  ///
  /// [subtitleLanguages] - Optional. If specified, results will be filtered based on subtitle language. This allows multiple, comma delimited values.
  ///
  /// [enableTotalRecordCount] - Optional. Enable the total record count.
  ///
  /// [enableImages] - Optional, include image information in output.
  @GET('/Items')
  Future<BaseItemDtoQueryResult> getItems({
    @Query('isNews') bool? isNews,
    @Query('maxOfficialRating') String? maxOfficialRating,
    @Query('hasThemeSong') bool? hasThemeSong,
    @Query('hasThemeVideo') bool? hasThemeVideo,
    @Query('hasSubtitles') bool? hasSubtitles,
    @Query('hasSpecialFeature') bool? hasSpecialFeature,
    @Query('hasTrailer') bool? hasTrailer,
    @Query('adjacentTo') String? adjacentTo,
    @Query('indexNumber') int? indexNumber,
    @Query('parentIndexNumber') int? parentIndexNumber,
    @Query('hasParentalRating') bool? hasParentalRating,
    @Query('isHd') bool? isHd,
    @Query('is4K') bool? is4K,
    @Query('locationTypes') List<LocationType>? locationTypes,
    @Query('excludeLocationTypes') List<LocationType>? excludeLocationTypes,
    @Query('isMissing') bool? isMissing,
    @Query('isUnaired') bool? isUnaired,
    @Query('minCommunityRating') double? minCommunityRating,
    @Query('minCriticRating') double? minCriticRating,
    @Query('minPremiereDate') DateTime? minPremiereDate,
    @Query('minDateLastSaved') DateTime? minDateLastSaved,
    @Query('minDateLastSavedForUser') DateTime? minDateLastSavedForUser,
    @Query('maxPremiereDate') DateTime? maxPremiereDate,
    @Query('hasOverview') bool? hasOverview,
    @Query('hasImdbId') bool? hasImdbId,
    @Query('hasTmdbId') bool? hasTmdbId,
    @Query('hasTvdbId') bool? hasTvdbId,
    @Query('isMovie') bool? isMovie,
    @Query('isSeries') bool? isSeries,
    @Query('userId') String? userId,
    @Query('isKids') bool? isKids,
    @Query('isSports') bool? isSports,
    @Query('excludeItemIds') List<String>? excludeItemIds,
    @Query('startIndex') int? startIndex,
    @Query('limit') int? limit,
    @Query('recursive') bool? recursive,
    @Query('searchTerm') String? searchTerm,
    @Query('sortOrder') List<SortOrder>? sortOrder,
    @Query('parentId') String? parentId,
    @Query('fields') List<ItemFields>? fields,
    @Query('excludeItemTypes') List<BaseItemKind>? excludeItemTypes,
    @Query('includeItemTypes') List<BaseItemKind>? includeItemTypes,
    @Query('filters') List<ItemFilter>? filters,
    @Query('isFavorite') bool? isFavorite,
    @Query('mediaTypes') List<MediaType>? mediaTypes,
    @Query('imageTypes') List<ImageType>? imageTypes,
    @Query('sortBy') List<ItemSortBy>? sortBy,
    @Query('isPlayed') bool? isPlayed,
    @Query('genres') List<String>? genres,
    @Query('officialRatings') List<String>? officialRatings,
    @Query('tags') List<String>? tags,
    @Query('years') List<int>? years,
    @Query('enableUserData') bool? enableUserData,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
    @Query('person') String? person,
    @Query('personIds') List<String>? personIds,
    @Query('subtitleLanguages') List<String>? subtitleLanguages,
    @Query('studios') List<String>? studios,
    @Query('artists') List<String>? artists,
    @Query('excludeArtistIds') List<String>? excludeArtistIds,
    @Query('artistIds') List<String>? artistIds,
    @Query('albumArtistIds') List<String>? albumArtistIds,
    @Query('contributingArtistIds') List<String>? contributingArtistIds,
    @Query('albums') List<String>? albums,
    @Query('albumIds') List<String>? albumIds,
    @Query('ids') List<String>? ids,
    @Query('videoTypes') List<VideoType>? videoTypes,
    @Query('minOfficialRating') String? minOfficialRating,
    @Query('isLocked') bool? isLocked,
    @Query('isPlaceHolder') bool? isPlaceHolder,
    @Query('hasOfficialRating') bool? hasOfficialRating,
    @Query('collapseBoxSetItems') bool? collapseBoxSetItems,
    @Query('minWidth') int? minWidth,
    @Query('minHeight') int? minHeight,
    @Query('maxWidth') int? maxWidth,
    @Query('maxHeight') int? maxHeight,
    @Query('is3D') bool? is3D,
    @Query('seriesStatus') List<SeriesStatus>? seriesStatus,
    @Query('nameStartsWithOrGreater') String? nameStartsWithOrGreater,
    @Query('nameStartsWith') String? nameStartsWith,
    @Query('nameLessThan') String? nameLessThan,
    @Query('studioIds') List<String>? studioIds,
    @Query('genreIds') List<String>? genreIds,
    @Query('audioLanguages') List<String>? audioLanguages,
    @Query('personTypes') List<String>? personTypes,
    @Query('enableTotalRecordCount') bool? enableTotalRecordCount = true,
    @Query('enableImages') bool? enableImages = true,
  });

  /// Deletes items from the library and filesystem.
  ///
  /// [ids] - The item ids.
  @DELETE('/Items')
  Future<void> deleteItems({
    @Query('ids') List<String>? ids,
  });

  /// Gets items based on a query.
  ///
  /// [userId] - The user id.
  ///
  /// [startIndex] - The start index.
  ///
  /// [limit] - The item limit.
  ///
  /// [searchTerm] - The search term.
  ///
  /// [parentId] - Specify this to localize the search to a specific item or folder. Omit to use the root.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output. This allows multiple, comma delimited. Options: Budget, Chapters, DateCreated, Genres, HomePageUrl, IndexOptions, MediaStreams, Overview, ParentId, Path, People, ProviderIds, PrimaryImageAspectRatio, Revenue, SortName, Studios, Taglines.
  ///
  /// [mediaTypes] - Optional. Filter by MediaType. Allows multiple, comma delimited.
  ///
  /// [enableUserData] - Optional. Include user data.
  ///
  /// [imageTypeLimit] - Optional. The max number of images to return, per image type.
  ///
  /// [enableImageTypes] - Optional. The image types to include in the output.
  ///
  /// [excludeItemTypes] - Optional. If specified, results will be filtered based on item type. This allows multiple, comma delimited.
  ///
  /// [includeItemTypes] - Optional. If specified, results will be filtered based on the item type. This allows multiple, comma delimited.
  ///
  /// [enableTotalRecordCount] - Optional. Enable the total record count.
  ///
  /// [enableImages] - Optional. Include image information in output.
  ///
  /// [excludeActiveSessions] - Optional. Whether to exclude the currently active sessions.
  @GET('/UserItems/Resume')
  Future<BaseItemDtoQueryResult> getResumeItems({
    @Query('enableTotalRecordCount') bool? enableTotalRecordCount = true,
    @Query('enableImages') bool? enableImages = true,
    @Query('excludeActiveSessions') bool? excludeActiveSessions = false,
    @Query('userId') String? userId,
    @Query('startIndex') int? startIndex,
    @Query('limit') int? limit,
    @Query('searchTerm') String? searchTerm,
    @Query('parentId') String? parentId,
    @Query('fields') List<ItemFields>? fields,
    @Query('mediaTypes') List<MediaType>? mediaTypes,
    @Query('enableUserData') bool? enableUserData,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
    @Query('excludeItemTypes') List<BaseItemKind>? excludeItemTypes,
    @Query('includeItemTypes') List<BaseItemKind>? includeItemTypes,
  });

  /// Deletes an item from the library and filesystem.
  ///
  /// [itemId] - The item id.
  @DELETE('/Items/{itemId}')
  Future<void> deleteItem({
    @Path('itemId') required String itemId,
  });

  /// Gets an item from a user's library.
  ///
  /// [userId] - User id.
  ///
  /// [itemId] - Item id.
  @GET('/Items/{itemId}')
  Future<BaseItemDto> getItem({
    @Path('itemId') required String itemId,
    @Query('userId') String? userId,
  });

  /// Gets similar items.
  ///
  /// [itemId] - The item id.
  ///
  /// [excludeArtistIds] - Exclude artist ids.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output. This allows multiple, comma delimited. Options: Budget, Chapters, DateCreated, Genres, HomePageUrl, IndexOptions, MediaStreams, Overview, ParentId, Path, People, ProviderIds, PrimaryImageAspectRatio, Revenue, SortName, Studios, Taglines, TrailerUrls.
  @GET('/Albums/{itemId}/Similar')
  Future<BaseItemDtoQueryResult> getSimilarAlbums({
    @Path('itemId') required String itemId,
    @Query('excludeArtistIds') List<String>? excludeArtistIds,
    @Query('userId') String? userId,
    @Query('limit') int? limit,
    @Query('fields') List<ItemFields>? fields,
  });

  /// Gets similar items.
  ///
  /// [itemId] - The item id.
  ///
  /// [excludeArtistIds] - Exclude artist ids.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output. This allows multiple, comma delimited. Options: Budget, Chapters, DateCreated, Genres, HomePageUrl, IndexOptions, MediaStreams, Overview, ParentId, Path, People, ProviderIds, PrimaryImageAspectRatio, Revenue, SortName, Studios, Taglines, TrailerUrls.
  @GET('/Artists/{itemId}/Similar')
  Future<BaseItemDtoQueryResult> getSimilarArtists({
    @Path('itemId') required String itemId,
    @Query('excludeArtistIds') List<String>? excludeArtistIds,
    @Query('userId') String? userId,
    @Query('limit') int? limit,
    @Query('fields') List<ItemFields>? fields,
  });

  /// Gets all parents of an item.
  ///
  /// [itemId] - The item id.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  @GET('/Items/{itemId}/Ancestors')
  Future<List<BaseItemDto>> getAncestors({
    @Path('itemId') required String itemId,
    @Query('userId') String? userId,
  });

  /// Gets the collections that include the specified item.
  ///
  /// [itemId] - The item id.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  ///
  /// [startIndex] - Optional. The index of the first record in the output.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output.
  @GET('/Items/{itemId}/Collections')
  Future<BaseItemDtoQueryResult> getItemCollections({
    @Path('itemId') required String itemId,
    @Query('userId') String? userId,
    @Query('startIndex') int? startIndex,
    @Query('limit') int? limit,
    @Query('fields') List<ItemFields>? fields,
  });

  /// Downloads item media.
  ///
  /// [itemId] - The item id.
  @GET('/Items/{itemId}/Download')
  @DioResponseType(ResponseType.stream)
  Stream<String> getDownload({
    @Path('itemId') required String itemId,
  });

  /// Get the original file of an item.
  ///
  /// [itemId] - The item id.
  @GET('/Items/{itemId}/File')
  @DioResponseType(ResponseType.stream)
  Stream<String> getFile({
    @Path('itemId') required String itemId,
  });

  /// Gets similar items.
  ///
  /// [itemId] - The item id.
  ///
  /// [excludeArtistIds] - Exclude artist ids.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output. This allows multiple, comma delimited. Options: Budget, Chapters, DateCreated, Genres, HomePageUrl, IndexOptions, MediaStreams, Overview, ParentId, Path, People, ProviderIds, PrimaryImageAspectRatio, Revenue, SortName, Studios, Taglines, TrailerUrls.
  @GET('/Items/{itemId}/Similar')
  Future<BaseItemDtoQueryResult> getSimilarItems({
    @Path('itemId') required String itemId,
    @Query('excludeArtistIds') List<String>? excludeArtistIds,
    @Query('userId') String? userId,
    @Query('limit') int? limit,
    @Query('fields') List<ItemFields>? fields,
  });

  /// Get theme songs and videos for an item.
  ///
  /// [itemId] - The item id.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  ///
  /// [inheritFromParent] - Optional. Determines whether or not parent items should be searched for theme media.
  ///
  /// [sortBy] - Optional. Specify one or more sort orders, comma delimited. Options: Album, AlbumArtist, Artist, Budget, CommunityRating, CriticRating, DateCreated, DatePlayed, PlayCount, PremiereDate, ProductionYear, SortName, Random, Revenue, Runtime.
  ///
  /// [sortOrder] - Optional. Sort Order - Ascending, Descending.
  @GET('/Items/{itemId}/ThemeMedia')
  Future<AllThemeMediaResult> getThemeMedia({
    @Path('itemId') required String itemId,
    @Query('inheritFromParent') bool? inheritFromParent = false,
    @Query('userId') String? userId,
    @Query('sortBy') List<ItemSortBy>? sortBy,
    @Query('sortOrder') List<SortOrder>? sortOrder,
  });

  /// Get theme songs for an item.
  ///
  /// [itemId] - The item id.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  ///
  /// [inheritFromParent] - Optional. Determines whether or not parent items should be searched for theme media.
  ///
  /// [sortBy] - Optional. Specify one or more sort orders, comma delimited. Options: Album, AlbumArtist, Artist, Budget, CommunityRating, CriticRating, DateCreated, DatePlayed, PlayCount, PremiereDate, ProductionYear, SortName, Random, Revenue, Runtime.
  ///
  /// [sortOrder] - Optional. Sort Order - Ascending, Descending.
  @GET('/Items/{itemId}/ThemeSongs')
  Future<ThemeMediaResult> getThemeSongs({
    @Path('itemId') required String itemId,
    @Query('inheritFromParent') bool? inheritFromParent = false,
    @Query('userId') String? userId,
    @Query('sortBy') List<ItemSortBy>? sortBy,
    @Query('sortOrder') List<SortOrder>? sortOrder,
  });

  /// Get theme videos for an item.
  ///
  /// [itemId] - The item id.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  ///
  /// [inheritFromParent] - Optional. Determines whether or not parent items should be searched for theme media.
  ///
  /// [sortBy] - Optional. Specify one or more sort orders, comma delimited. Options: Album, AlbumArtist, Artist, Budget, CommunityRating, CriticRating, DateCreated, DatePlayed, PlayCount, PremiereDate, ProductionYear, SortName, Random, Revenue, Runtime.
  ///
  /// [sortOrder] - Optional. Sort Order - Ascending, Descending.
  @GET('/Items/{itemId}/ThemeVideos')
  Future<ThemeMediaResult> getThemeVideos({
    @Path('itemId') required String itemId,
    @Query('inheritFromParent') bool? inheritFromParent = false,
    @Query('userId') String? userId,
    @Query('sortBy') List<ItemSortBy>? sortBy,
    @Query('sortOrder') List<SortOrder>? sortOrder,
  });

  /// Get item counts.
  ///
  /// [userId] - Optional. Get counts from a specific user's library.
  ///
  /// [isFavorite] - Optional. Get counts of favorite items.
  @GET('/Items/Counts')
  Future<ItemCounts> getItemCounts({
    @Query('userId') String? userId,
    @Query('isFavorite') bool? isFavorite,
  });

  /// Gets the library options info.
  ///
  /// [libraryContentType] - Library content type.
  ///
  /// [isNewLibrary] - Whether this is a new library.
  @GET('/Libraries/AvailableOptions')
  Future<LibraryOptionsResultDto> getLibraryOptionsInfo({
    @Query('isNewLibrary') bool? isNewLibrary = false,
    @Query('libraryContentType') LibraryContentType? libraryContentType,
  });

  /// Reports that new movies have been added by an external source.
  ///
  /// [body] - Media Update Info Dto.
  @POST('/Library/Media/Updated')
  Future<void> postUpdatedMedia({
    @Body() required MediaUpdateInfoDto body,
  });

  /// Gets all user media folders.
  ///
  /// [isHidden] - Optional. Filter by folders that are marked hidden, or not.
  @GET('/Library/MediaFolders')
  Future<BaseItemDtoQueryResult> getMediaFolders({
    @Query('isHidden') bool? isHidden,
  });

  /// Reports that new movies have been added by an external source.
  ///
  /// [tmdbId] - The tmdbId.
  ///
  /// [imdbId] - The imdbId.
  @POST('/Library/Movies/Added')
  Future<void> postAddedMovies({
    @Query('tmdbId') String? tmdbId,
    @Query('imdbId') String? imdbId,
  });

  /// Reports that new movies have been added by an external source.
  ///
  /// [tmdbId] - The tmdbId.
  ///
  /// [imdbId] - The imdbId.
  @POST('/Library/Movies/Updated')
  Future<void> postUpdatedMovies({
    @Query('tmdbId') String? tmdbId,
    @Query('imdbId') String? imdbId,
  });

  /// Gets a list of physical paths from virtual folders.
  @GET('/Library/PhysicalPaths')
  Future<List<String>> getPhysicalPaths();

  /// Starts a library scan.
  @POST('/Library/Refresh')
  Future<void> refreshLibrary();

  /// Reports that new episodes of a series have been added by an external source.
  ///
  /// [tvdbId] - The tvdbId.
  @POST('/Library/Series/Added')
  Future<void> postAddedSeries({
    @Query('tvdbId') String? tvdbId,
  });

  /// Reports that new episodes of a series have been added by an external source.
  ///
  /// [tvdbId] - The tvdbId.
  @POST('/Library/Series/Updated')
  Future<void> postUpdatedSeries({
    @Query('tvdbId') String? tvdbId,
  });

  /// Gets similar items.
  ///
  /// [itemId] - The item id.
  ///
  /// [excludeArtistIds] - Exclude artist ids.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output. This allows multiple, comma delimited. Options: Budget, Chapters, DateCreated, Genres, HomePageUrl, IndexOptions, MediaStreams, Overview, ParentId, Path, People, ProviderIds, PrimaryImageAspectRatio, Revenue, SortName, Studios, Taglines, TrailerUrls.
  @GET('/Movies/{itemId}/Similar')
  Future<BaseItemDtoQueryResult> getSimilarMovies({
    @Path('itemId') required String itemId,
    @Query('excludeArtistIds') List<String>? excludeArtistIds,
    @Query('userId') String? userId,
    @Query('limit') int? limit,
    @Query('fields') List<ItemFields>? fields,
  });

  /// Gets similar items.
  ///
  /// [itemId] - The item id.
  ///
  /// [excludeArtistIds] - Exclude artist ids.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output. This allows multiple, comma delimited. Options: Budget, Chapters, DateCreated, Genres, HomePageUrl, IndexOptions, MediaStreams, Overview, ParentId, Path, People, ProviderIds, PrimaryImageAspectRatio, Revenue, SortName, Studios, Taglines, TrailerUrls.
  @GET('/Shows/{itemId}/Similar')
  Future<BaseItemDtoQueryResult> getSimilarShows({
    @Path('itemId') required String itemId,
    @Query('excludeArtistIds') List<String>? excludeArtistIds,
    @Query('userId') String? userId,
    @Query('limit') int? limit,
    @Query('fields') List<ItemFields>? fields,
  });

  /// Gets similar items.
  ///
  /// [itemId] - The item id.
  ///
  /// [excludeArtistIds] - Exclude artist ids.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output. This allows multiple, comma delimited. Options: Budget, Chapters, DateCreated, Genres, HomePageUrl, IndexOptions, MediaStreams, Overview, ParentId, Path, People, ProviderIds, PrimaryImageAspectRatio, Revenue, SortName, Studios, Taglines, TrailerUrls.
  @GET('/Trailers/{itemId}/Similar')
  Future<BaseItemDtoQueryResult> getSimilarTrailers({
    @Path('itemId') required String itemId,
    @Query('excludeArtistIds') List<String>? excludeArtistIds,
    @Query('userId') String? userId,
    @Query('limit') int? limit,
    @Query('fields') List<ItemFields>? fields,
  });

  /// Gets intros to play before the main media item plays.
  ///
  /// [userId] - User id.
  ///
  /// [itemId] - Item id.
  @GET('/Items/{itemId}/Intros')
  Future<BaseItemDtoQueryResult> getIntros({
    @Path('itemId') required String itemId,
    @Query('userId') String? userId,
  });

  /// Gets local trailers for an item.
  ///
  /// [userId] - User id.
  ///
  /// [itemId] - Item id.
  @GET('/Items/{itemId}/LocalTrailers')
  Future<List<BaseItemDto>> getLocalTrailers({
    @Path('itemId') required String itemId,
    @Query('userId') String? userId,
  });

  /// Gets special features for an item.
  ///
  /// [userId] - User id.
  ///
  /// [itemId] - Item id.
  @GET('/Items/{itemId}/SpecialFeatures')
  Future<List<BaseItemDto>> getSpecialFeatures({
    @Path('itemId') required String itemId,
    @Query('userId') String? userId,
  });

  /// Gets latest media.
  ///
  /// [userId] - User id.
  ///
  /// [parentId] - Specify this to localize the search to a specific item or folder. Omit to use the root.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output.
  ///
  /// [includeItemTypes] - Optional. If specified, results will be filtered based on item type. This allows multiple, comma delimited.
  ///
  /// [isPlayed] - Filter by items that are played, or not.
  ///
  /// [enableImages] - Optional. include image information in output.
  ///
  /// [imageTypeLimit] - Optional. the max number of images to return, per image type.
  ///
  /// [enableImageTypes] - Optional. The image types to include in the output.
  ///
  /// [enableUserData] - Optional. include user data.
  ///
  /// [limit] - Return item limit.
  ///
  /// [groupItems] - Whether or not to group items into a parent container.
  @GET('/Items/Latest')
  Future<List<BaseItemDto>> getLatestMedia({
    @Query('limit') int? limit = 20,
    @Query('groupItems') bool? groupItems = true,
    @Query('userId') String? userId,
    @Query('parentId') String? parentId,
    @Query('fields') List<ItemFields>? fields,
    @Query('includeItemTypes') List<BaseItemKind>? includeItemTypes,
    @Query('isPlayed') bool? isPlayed,
    @Query('enableImages') bool? enableImages,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
    @Query('enableUserData') bool? enableUserData,
  });

  /// Gets the root folder from a user's library.
  ///
  /// [userId] - User id.
  @GET('/Items/Root')
  Future<BaseItemDto> getRootFolder({
    @Query('userId') String? userId,
  });
}
