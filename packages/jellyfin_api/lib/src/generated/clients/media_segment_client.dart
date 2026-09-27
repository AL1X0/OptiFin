// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/media_segment_dto_query_result.dart';
import '../models/media_segment_type.dart';

part 'media_segment_client.g.dart';

@RestApi()
abstract class MediaSegmentClient {
  factory MediaSegmentClient(Dio dio, {String? baseUrl}) = _MediaSegmentClient;

  /// Gets all media segments based on an itemId.
  ///
  /// [itemId] - The ItemId.
  ///
  /// [includeSegmentTypes] - Optional filter of requested segment types.
  @GET('/MediaSegments/{itemId}')
  Future<MediaSegmentDtoQueryResult> getItemSegments({
    @Path('itemId') required String itemId,
    @Query('includeSegmentTypes') List<MediaSegmentType>? includeSegmentTypes,
  });
}
