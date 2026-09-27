// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/base_item_kind.dart';
import '../models/media_type.dart';
import '../models/query_filters.dart';
import '../models/query_filters_legacy.dart';

part 'filter_client.g.dart';

@RestApi()
abstract class FilterClient {
  factory FilterClient(Dio dio, {String? baseUrl}) = _FilterClient;

  /// Gets legacy query filters.
  ///
  /// [userId] - Optional. User id.
  ///
  /// [parentId] - Optional. Parent id.
  ///
  /// [includeItemTypes] - Optional. If specified, results will be filtered based on item type. This allows multiple, comma delimited.
  ///
  /// [mediaTypes] - Optional. Filter by MediaType. Allows multiple, comma delimited.
  @GET('/Items/Filters')
  Future<QueryFiltersLegacy> getQueryFiltersLegacy({
    @Query('userId') String? userId,
    @Query('parentId') String? parentId,
    @Query('includeItemTypes') List<BaseItemKind>? includeItemTypes,
    @Query('mediaTypes') List<MediaType>? mediaTypes,
  });

  /// Gets query filters.
  ///
  /// [userId] - Optional. User id.
  ///
  /// [parentId] - Optional. Specify this to localize the search to a specific item or folder. Omit to use the root.
  ///
  /// [includeItemTypes] - Optional. If specified, results will be filtered based on item type. This allows multiple, comma delimited.
  ///
  /// [isAiring] - Optional. Is item airing.
  ///
  /// [isMovie] - Optional. Is item movie.
  ///
  /// [isSports] - Optional. Is item sports.
  ///
  /// [isKids] - Optional. Is item kids.
  ///
  /// [isNews] - Optional. Is item news.
  ///
  /// [isSeries] - Optional. Is item series.
  ///
  /// [recursive] - Optional. Search recursive.
  @GET('/Items/Filters2')
  Future<QueryFilters> getQueryFilters({
    @Query('userId') String? userId,
    @Query('parentId') String? parentId,
    @Query('includeItemTypes') List<BaseItemKind>? includeItemTypes,
    @Query('isAiring') bool? isAiring,
    @Query('isMovie') bool? isMovie,
    @Query('isSports') bool? isSports,
    @Query('isKids') bool? isKids,
    @Query('isNews') bool? isNews,
    @Query('isSeries') bool? isSeries,
    @Query('recursive') bool? recursive,
  });
}
