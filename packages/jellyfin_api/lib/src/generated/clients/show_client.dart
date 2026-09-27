// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/base_item_dto_query_result.dart';
import '../models/image_type.dart';
import '../models/item_fields.dart';
import '../models/sort_by.dart';

part 'show_client.g.dart';

@RestApi()
abstract class ShowClient {
  factory ShowClient(Dio dio, {String? baseUrl}) = _ShowClient;

  /// Gets episodes for a tv season.
  ///
  /// [seriesId] - The series id.
  ///
  /// [userId] - The user id.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output. This allows multiple, comma delimited. Options: Budget, Chapters, DateCreated, Genres, HomePageUrl, IndexOptions, MediaStreams, Overview, ParentId, Path, People, ProviderIds, PrimaryImageAspectRatio, Revenue, SortName, Studios, Taglines, TrailerUrls.
  ///
  /// [season] - Optional filter by season number.
  ///
  /// [seasonId] - Optional. Filter by season id.
  ///
  /// [isMissing] - Optional. Filter by items that are missing episodes or not.
  ///
  /// [adjacentTo] - Optional. Return items that are siblings of a supplied item.
  ///
  /// [startItemId] - Optional. Skip through the list until a given item is found.
  ///
  /// [startIndex] - Optional. The record index to start at. All items with a lower index will be dropped from the results.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [enableImages] - Optional, include image information in output.
  ///
  /// [imageTypeLimit] - Optional, the max number of images to return, per image type.
  ///
  /// [enableImageTypes] - Optional. The image types to include in the output.
  ///
  /// [enableUserData] - Optional. Include user data.
  ///
  /// [sortBy] - Optional. Specify one or more sort orders, comma delimited. Options: Album, AlbumArtist, Artist, Budget, CommunityRating, CriticRating, DateCreated, DatePlayed, PlayCount, PremiereDate, ProductionYear, SortName, Random, Revenue, Runtime.
  @GET('/Shows/{seriesId}/Episodes')
  Future<BaseItemDtoQueryResult> getEpisodes({
    @Path('seriesId') required String seriesId,
    @Query('userId') String? userId,
    @Query('fields') List<ItemFields>? fields,
    @Query('season') int? season,
    @Query('seasonId') String? seasonId,
    @Query('isMissing') bool? isMissing,
    @Query('adjacentTo') String? adjacentTo,
    @Query('startItemId') String? startItemId,
    @Query('startIndex') int? startIndex,
    @Query('limit') int? limit,
    @Query('enableImages') bool? enableImages,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
    @Query('enableUserData') bool? enableUserData,
    @Query('sortBy') SortBy? sortBy,
  });

  /// Gets seasons for a tv series.
  ///
  /// [seriesId] - The series id.
  ///
  /// [userId] - The user id.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output. This allows multiple, comma delimited. Options: Budget, Chapters, DateCreated, Genres, HomePageUrl, IndexOptions, MediaStreams, Overview, ParentId, Path, People, ProviderIds, PrimaryImageAspectRatio, Revenue, SortName, Studios, Taglines, TrailerUrls.
  ///
  /// [isSpecialSeason] - Optional. Filter by special season.
  ///
  /// [isMissing] - Optional. Filter by items that are missing episodes or not.
  ///
  /// [adjacentTo] - Optional. Return items that are siblings of a supplied item.
  ///
  /// [enableImages] - Optional. Include image information in output.
  ///
  /// [imageTypeLimit] - Optional. The max number of images to return, per image type.
  ///
  /// [enableImageTypes] - Optional. The image types to include in the output.
  ///
  /// [enableUserData] - Optional. Include user data.
  @GET('/Shows/{seriesId}/Seasons')
  Future<BaseItemDtoQueryResult> getSeasons({
    @Path('seriesId') required String seriesId,
    @Query('userId') String? userId,
    @Query('fields') List<ItemFields>? fields,
    @Query('isSpecialSeason') bool? isSpecialSeason,
    @Query('isMissing') bool? isMissing,
    @Query('adjacentTo') String? adjacentTo,
    @Query('enableImages') bool? enableImages,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
    @Query('enableUserData') bool? enableUserData,
  });

  /// Gets a list of next up episodes.
  ///
  /// [userId] - The user id of the user to get the next up episodes for.
  ///
  /// [startIndex] - Optional. The record index to start at. All items with a lower index will be dropped from the results.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output.
  ///
  /// [seriesId] - Optional. Filter by series id.
  ///
  /// [parentId] - Optional. Specify this to localize the search to a specific item or folder. Omit to use the root.
  ///
  /// [enableImages] - Optional. Include image information in output.
  ///
  /// [imageTypeLimit] - Optional. The max number of images to return, per image type.
  ///
  /// [enableImageTypes] - Optional. The image types to include in the output.
  ///
  /// [enableUserData] - Optional. Include user data.
  ///
  /// [nextUpDateCutoff] - Optional. Starting date of shows to show in Next Up section.
  ///
  /// [enableTotalRecordCount] - Whether to enable the total records count. Defaults to true.
  ///
  /// [enableResumable] - Whether to include resumable episodes in next up results.
  ///
  /// [enableRewatching] - Whether to include watched episodes in next up results.
  @GET('/Shows/NextUp')
  Future<BaseItemDtoQueryResult> getNextUp({
    @Query('enableTotalRecordCount') bool? enableTotalRecordCount = true,
    @Query('enableResumable') bool? enableResumable = true,
    @Query('enableRewatching') bool? enableRewatching = false,
    @Query('userId') String? userId,
    @Query('startIndex') int? startIndex,
    @Query('limit') int? limit,
    @Query('fields') List<ItemFields>? fields,
    @Query('seriesId') String? seriesId,
    @Query('parentId') String? parentId,
    @Query('enableImages') bool? enableImages,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
    @Query('enableUserData') bool? enableUserData,
    @Query('nextUpDateCutoff') DateTime? nextUpDateCutoff,
  });

  /// Gets a list of upcoming episodes.
  ///
  /// [userId] - The user id of the user to get the upcoming episodes for.
  ///
  /// [startIndex] - Optional. The record index to start at. All items with a lower index will be dropped from the results.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output.
  ///
  /// [parentId] - Optional. Specify this to localize the search to a specific item or folder. Omit to use the root.
  ///
  /// [enableImages] - Optional. Include image information in output.
  ///
  /// [imageTypeLimit] - Optional. The max number of images to return, per image type.
  ///
  /// [enableImageTypes] - Optional. The image types to include in the output.
  ///
  /// [enableUserData] - Optional. Include user data.
  @GET('/Shows/Upcoming')
  Future<BaseItemDtoQueryResult> getUpcomingEpisodes({
    @Query('userId') String? userId,
    @Query('startIndex') int? startIndex,
    @Query('limit') int? limit,
    @Query('fields') List<ItemFields>? fields,
    @Query('parentId') String? parentId,
    @Query('enableImages') bool? enableImages,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
    @Query('enableUserData') bool? enableUserData,
  });
}
