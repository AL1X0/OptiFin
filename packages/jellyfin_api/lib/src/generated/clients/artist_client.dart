// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/base_item_dto.dart';
import '../models/base_item_dto_query_result.dart';
import '../models/base_item_kind.dart';
import '../models/image_type.dart';
import '../models/item_fields.dart';
import '../models/item_filter.dart';
import '../models/item_sort_by.dart';
import '../models/media_type.dart';
import '../models/sort_order.dart';

part 'artist_client.g.dart';

@RestApi()
abstract class ArtistClient {
  factory ArtistClient(Dio dio, {String? baseUrl}) = _ArtistClient;

  /// Gets all artists from a given item, folder, or the entire library.
  ///
  /// [minCommunityRating] - Optional filter by minimum community rating.
  ///
  /// [startIndex] - Optional. The record index to start at. All items with a lower index will be dropped from the results.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [searchTerm] - Optional. Search term.
  ///
  /// [parentId] - Specify this to localize the search to a specific item or folder. Omit to use the root.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output.
  ///
  /// [excludeItemTypes] - Optional. If specified, results will be filtered out based on item type. This allows multiple, comma delimited.
  ///
  /// [includeItemTypes] - Optional. If specified, results will be filtered based on item type. This allows multiple, comma delimited.
  ///
  /// [filters] - Optional. Specify additional filters to apply.
  ///
  /// [isFavorite] - Optional filter by items that are marked as favorite, or not.
  ///
  /// [mediaTypes] - Optional filter by MediaType. Allows multiple, comma delimited.
  ///
  /// [genres] - Optional. If specified, results will be filtered based on genre. This allows multiple, pipe delimited.
  ///
  /// [genreIds] - Optional. If specified, results will be filtered based on genre id. This allows multiple, pipe delimited.
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
  /// [personIds] - Optional. If specified, results will be filtered to include only those containing the specified person ids.
  ///
  /// [personTypes] - Optional. If specified, along with Person, results will be filtered to include only those containing the specified person and PersonType. Allows multiple, comma-delimited.
  ///
  /// [studios] - Optional. If specified, results will be filtered based on studio. This allows multiple, pipe delimited.
  ///
  /// [studioIds] - Optional. If specified, results will be filtered based on studio id. This allows multiple, pipe delimited.
  ///
  /// [userId] - User id.
  ///
  /// [nameStartsWithOrGreater] - Optional filter by items whose name is sorted equally or greater than a given input string.
  ///
  /// [nameStartsWith] - Optional filter by items whose name is sorted equally than a given input string.
  ///
  /// [nameLessThan] - Optional filter by items whose name is equally or lesser than a given input string.
  ///
  /// [sortBy] - Optional. Specify one or more sort orders, comma delimited.
  ///
  /// [sortOrder] - Sort Order - Ascending,Descending.
  ///
  /// [enableImages] - Optional, include image information in output.
  ///
  /// [enableTotalRecordCount] - Total record count.
  @Deprecated('This method is marked as deprecated')
  @GET('/Artists')
  Future<BaseItemDtoQueryResult> getArtists({
    @Query('enableImages') bool? enableImages = true,
    @Query('enableTotalRecordCount') bool? enableTotalRecordCount = true,
    @Query('minCommunityRating') double? minCommunityRating,
    @Query('startIndex') int? startIndex,
    @Query('limit') int? limit,
    @Query('searchTerm') String? searchTerm,
    @Query('parentId') String? parentId,
    @Query('fields') List<ItemFields>? fields,
    @Query('excludeItemTypes') List<BaseItemKind>? excludeItemTypes,
    @Query('includeItemTypes') List<BaseItemKind>? includeItemTypes,
    @Query('filters') List<ItemFilter>? filters,
    @Query('isFavorite') bool? isFavorite,
    @Query('mediaTypes') List<MediaType>? mediaTypes,
    @Query('genres') List<String>? genres,
    @Query('genreIds') List<String>? genreIds,
    @Query('officialRatings') List<String>? officialRatings,
    @Query('tags') List<String>? tags,
    @Query('years') List<int>? years,
    @Query('enableUserData') bool? enableUserData,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
    @Query('person') String? person,
    @Query('personIds') List<String>? personIds,
    @Query('personTypes') List<String>? personTypes,
    @Query('studios') List<String>? studios,
    @Query('studioIds') List<String>? studioIds,
    @Query('userId') String? userId,
    @Query('nameStartsWithOrGreater') String? nameStartsWithOrGreater,
    @Query('nameStartsWith') String? nameStartsWith,
    @Query('nameLessThan') String? nameLessThan,
    @Query('sortBy') List<ItemSortBy>? sortBy,
    @Query('sortOrder') List<SortOrder>? sortOrder,
  });

  /// Gets an artist by name.
  ///
  /// [name] - Studio name.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  @Deprecated('This method is marked as deprecated')
  @GET('/Artists/{name}')
  Future<BaseItemDto> getArtistByName({
    @Path('name') required String name,
    @Query('userId') String? userId,
  });

  /// Gets all album artists from a given item, folder, or the entire library.
  ///
  /// [minCommunityRating] - Optional filter by minimum community rating.
  ///
  /// [startIndex] - Optional. The record index to start at. All items with a lower index will be dropped from the results.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [searchTerm] - Optional. Search term.
  ///
  /// [parentId] - Specify this to localize the search to a specific item or folder. Omit to use the root.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output.
  ///
  /// [excludeItemTypes] - Optional. If specified, results will be filtered out based on item type. This allows multiple, comma delimited.
  ///
  /// [includeItemTypes] - Optional. If specified, results will be filtered based on item type. This allows multiple, comma delimited.
  ///
  /// [filters] - Optional. Specify additional filters to apply.
  ///
  /// [isFavorite] - Optional filter by items that are marked as favorite, or not.
  ///
  /// [mediaTypes] - Optional filter by MediaType. Allows multiple, comma delimited.
  ///
  /// [genres] - Optional. If specified, results will be filtered based on genre. This allows multiple, pipe delimited.
  ///
  /// [genreIds] - Optional. If specified, results will be filtered based on genre id. This allows multiple, pipe delimited.
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
  /// [personIds] - Optional. If specified, results will be filtered to include only those containing the specified person ids.
  ///
  /// [personTypes] - Optional. If specified, along with Person, results will be filtered to include only those containing the specified person and PersonType. Allows multiple, comma-delimited.
  ///
  /// [studios] - Optional. If specified, results will be filtered based on studio. This allows multiple, pipe delimited.
  ///
  /// [studioIds] - Optional. If specified, results will be filtered based on studio id. This allows multiple, pipe delimited.
  ///
  /// [userId] - User id.
  ///
  /// [nameStartsWithOrGreater] - Optional filter by items whose name is sorted equally or greater than a given input string.
  ///
  /// [nameStartsWith] - Optional filter by items whose name is sorted equally than a given input string.
  ///
  /// [nameLessThan] - Optional filter by items whose name is equally or lesser than a given input string.
  ///
  /// [sortBy] - Optional. Specify one or more sort orders, comma delimited.
  ///
  /// [sortOrder] - Sort Order - Ascending,Descending.
  ///
  /// [enableImages] - Optional, include image information in output.
  ///
  /// [enableTotalRecordCount] - Total record count.
  @Deprecated('This method is marked as deprecated')
  @GET('/Artists/AlbumArtists')
  Future<BaseItemDtoQueryResult> getAlbumArtists({
    @Query('enableImages') bool? enableImages = true,
    @Query('enableTotalRecordCount') bool? enableTotalRecordCount = true,
    @Query('minCommunityRating') double? minCommunityRating,
    @Query('startIndex') int? startIndex,
    @Query('limit') int? limit,
    @Query('searchTerm') String? searchTerm,
    @Query('parentId') String? parentId,
    @Query('fields') List<ItemFields>? fields,
    @Query('excludeItemTypes') List<BaseItemKind>? excludeItemTypes,
    @Query('includeItemTypes') List<BaseItemKind>? includeItemTypes,
    @Query('filters') List<ItemFilter>? filters,
    @Query('isFavorite') bool? isFavorite,
    @Query('mediaTypes') List<MediaType>? mediaTypes,
    @Query('genres') List<String>? genres,
    @Query('genreIds') List<String>? genreIds,
    @Query('officialRatings') List<String>? officialRatings,
    @Query('tags') List<String>? tags,
    @Query('years') List<int>? years,
    @Query('enableUserData') bool? enableUserData,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
    @Query('person') String? person,
    @Query('personIds') List<String>? personIds,
    @Query('personTypes') List<String>? personTypes,
    @Query('studios') List<String>? studios,
    @Query('studioIds') List<String>? studioIds,
    @Query('userId') String? userId,
    @Query('nameStartsWithOrGreater') String? nameStartsWithOrGreater,
    @Query('nameStartsWith') String? nameStartsWith,
    @Query('nameLessThan') String? nameLessThan,
    @Query('sortBy') List<ItemSortBy>? sortBy,
    @Query('sortOrder') List<SortOrder>? sortOrder,
  });
}
