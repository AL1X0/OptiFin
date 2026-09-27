// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/item_fields.dart';
import '../models/recommendation_dto.dart';

part 'movie_client.g.dart';

@RestApi()
abstract class MovieClient {
  factory MovieClient(Dio dio, {String? baseUrl}) = _MovieClient;

  /// Gets movie recommendations.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  ///
  /// [parentId] - Specify this to localize the search to a specific item or folder. Omit to use the root.
  ///
  /// [fields] - Optional. The fields to return.
  ///
  /// [categoryLimit] - The max number of categories to return.
  ///
  /// [itemLimit] - The max number of items to return per category.
  @GET('/Movies/Recommendations')
  Future<List<RecommendationDto>> getMovieRecommendations({
    @Query('categoryLimit') int? categoryLimit = 5,
    @Query('itemLimit') int? itemLimit = 8,
    @Query('userId') String? userId,
    @Query('parentId') String? parentId,
    @Query('fields') List<ItemFields>? fields,
  });
}
