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
import '../models/media_type.dart';
import '../models/sort_order.dart';

part 'year_client.g.dart';

@RestApi()
abstract class YearClient {
  factory YearClient(Dio dio, {String? baseUrl}) = _YearClient;

  /// Get years.
  ///
  /// [startIndex] - Skips over a given number of items within the results. Use for paging.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [sortOrder] - Sort Order - Ascending,Descending.
  ///
  /// [parentId] - Specify this to localize the search to a specific item or folder. Omit to use the root.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output.
  ///
  /// [excludeItemTypes] - Optional. If specified, results will be excluded based on item type. This allows multiple, comma delimited.
  ///
  /// [includeItemTypes] - Optional. If specified, results will be included based on item type. This allows multiple, comma delimited.
  ///
  /// [mediaTypes] - Optional. Filter by MediaType. Allows multiple, comma delimited.
  ///
  /// [sortBy] - Optional. Specify one or more sort orders, comma delimited. Options: Album, AlbumArtist, Artist, Budget, CommunityRating, CriticRating, DateCreated, DatePlayed, PlayCount, PremiereDate, ProductionYear, SortName, Random, Revenue, Runtime.
  ///
  /// [enableUserData] - Optional. Include user data.
  ///
  /// [imageTypeLimit] - Optional. The max number of images to return, per image type.
  ///
  /// [enableImageTypes] - Optional. The image types to include in the output.
  ///
  /// [userId] - User Id.
  ///
  /// [recursive] - Search recursively.
  ///
  /// [enableImages] - Optional. Include image information in output.
  @GET('/Years')
  Future<BaseItemDtoQueryResult> getYears({
    @Query('recursive') bool? recursive = true,
    @Query('enableImages') bool? enableImages = true,
    @Query('startIndex') int? startIndex,
    @Query('limit') int? limit,
    @Query('sortOrder') List<SortOrder>? sortOrder,
    @Query('parentId') String? parentId,
    @Query('fields') List<ItemFields>? fields,
    @Query('excludeItemTypes') List<BaseItemKind>? excludeItemTypes,
    @Query('includeItemTypes') List<BaseItemKind>? includeItemTypes,
    @Query('mediaTypes') List<MediaType>? mediaTypes,
    @Query('sortBy') List<ItemSortBy>? sortBy,
    @Query('enableUserData') bool? enableUserData,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
    @Query('userId') String? userId,
  });

  /// Gets a year.
  ///
  /// [year] - The year.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  @GET('/Years/{year}')
  Future<BaseItemDto> getYear({
    @Path('year') required int year,
    @Query('userId') String? userId,
  });
}
