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
import '../models/item_sort_by.dart';
import '../models/sort_order.dart';

part 'genre_client.g.dart';

@RestApi()
abstract class GenreClient {
  factory GenreClient(Dio dio, {String? baseUrl}) = _GenreClient;

  /// Gets all genres from a given item, folder, or the entire library.
  ///
  /// [startIndex] - Optional. The record index to start at. All items with a lower index will be dropped from the results.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [searchTerm] - The search term.
  ///
  /// [parentId] - Specify this to localize the search to a specific item or folder. Omit to use the root.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output.
  ///
  /// [excludeItemTypes] - Optional. If specified, results will be filtered out based on item type. This allows multiple, comma delimited.
  ///
  /// [includeItemTypes] - Optional. If specified, results will be filtered in based on item type. This allows multiple, comma delimited.
  ///
  /// [isFavorite] - Optional filter by items that are marked as favorite, or not.
  ///
  /// [imageTypeLimit] - Optional, the max number of images to return, per image type.
  ///
  /// [enableImageTypes] - Optional. The image types to include in the output.
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
  /// [enableTotalRecordCount] - Optional. Include total record count.
  @GET('/Genres')
  Future<BaseItemDtoQueryResult> getGenres({
    @Query('enableImages') bool? enableImages = true,
    @Query('enableTotalRecordCount') bool? enableTotalRecordCount = true,
    @Query('startIndex') int? startIndex,
    @Query('limit') int? limit,
    @Query('searchTerm') String? searchTerm,
    @Query('parentId') String? parentId,
    @Query('fields') List<ItemFields>? fields,
    @Query('excludeItemTypes') List<BaseItemKind>? excludeItemTypes,
    @Query('includeItemTypes') List<BaseItemKind>? includeItemTypes,
    @Query('isFavorite') bool? isFavorite,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
    @Query('userId') String? userId,
    @Query('nameStartsWithOrGreater') String? nameStartsWithOrGreater,
    @Query('nameStartsWith') String? nameStartsWith,
    @Query('nameLessThan') String? nameLessThan,
    @Query('sortBy') List<ItemSortBy>? sortBy,
    @Query('sortOrder') List<SortOrder>? sortOrder,
  });

  /// Gets a genre, by name.
  ///
  /// [genreName] - The genre name.
  ///
  /// [userId] - The user id.
  @GET('/Genres/{genreName}')
  Future<BaseItemDto> getGenre({
    @Path('genreName') required String genreName,
    @Query('userId') String? userId,
  });
}
