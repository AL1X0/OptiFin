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

part 'studio_client.g.dart';

@RestApi()
abstract class StudioClient {
  factory StudioClient(Dio dio, {String? baseUrl}) = _StudioClient;

  /// Gets all studios from a given item, folder, or the entire library.
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
  /// [isFavorite] - Optional filter by items that are marked as favorite, or not.
  ///
  /// [enableUserData] - Optional, include user data.
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
  /// [enableImages] - Optional, include image information in output.
  ///
  /// [enableTotalRecordCount] - Total record count.
  @GET('/Studios')
  Future<BaseItemDtoQueryResult> getStudios({
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
    @Query('enableUserData') bool? enableUserData,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
    @Query('userId') String? userId,
    @Query('nameStartsWithOrGreater') String? nameStartsWithOrGreater,
    @Query('nameStartsWith') String? nameStartsWith,
    @Query('nameLessThan') String? nameLessThan,
  });

  /// Gets a studio by name.
  ///
  /// [name] - Studio name.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  @GET('/Studios/{name}')
  Future<BaseItemDto> getStudio({
    @Path('name') required String name,
    @Query('userId') String? userId,
  });
}
