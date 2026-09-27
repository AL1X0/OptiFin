// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/base_item_dto_query_result.dart';
import '../models/base_item_kind.dart';
import '../models/media_type.dart';

part 'suggestion_client.g.dart';

@RestApi()
abstract class SuggestionClient {
  factory SuggestionClient(Dio dio, {String? baseUrl}) = _SuggestionClient;

  /// Gets suggestions.
  ///
  /// [userId] - The user id.
  ///
  /// [mediaType] - The media types.
  ///
  /// [type] - The type.
  ///
  /// [startIndex] - Optional. The start index.
  ///
  /// [limit] - Optional. The limit.
  ///
  /// [enableTotalRecordCount] - Whether to enable the total record count.
  @GET('/Items/Suggestions')
  Future<BaseItemDtoQueryResult> getSuggestions({
    @Query('enableTotalRecordCount') bool? enableTotalRecordCount = false,
    @Query('userId') String? userId,
    @Query('mediaType') List<MediaType>? mediaType,
    @Query('type') List<BaseItemKind>? type,
    @Query('startIndex') int? startIndex,
    @Query('limit') int? limit,
  });
}
