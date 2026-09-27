// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/base_item_kind.dart';
import '../models/media_type.dart';
import '../models/search_hint_result.dart';

part 'search_client.g.dart';

@RestApi()
abstract class SearchClient {
  factory SearchClient(Dio dio, {String? baseUrl}) = _SearchClient;

  /// Gets the search hint result.
  ///
  /// [startIndex] - Optional. The record index to start at. All items with a lower index will be dropped from the results.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [userId] - Optional. Supply a user id to search within a user's library or omit to search all.
  ///
  /// [searchTerm] - The search term to filter on.
  ///
  /// [includeItemTypes] - If specified, only results with the specified item types are returned. This allows multiple, comma delimited.
  ///
  /// [excludeItemTypes] - If specified, results with these item types are filtered out. This allows multiple, comma delimited.
  ///
  /// [mediaTypes] - If specified, only results with the specified media types are returned. This allows multiple, comma delimited.
  ///
  /// [parentId] - If specified, only children of the parent are returned.
  ///
  /// [isMovie] - Optional filter for movies.
  ///
  /// [isSeries] - Optional filter for series.
  ///
  /// [isNews] - Optional filter for news.
  ///
  /// [isKids] - Optional filter for kids.
  ///
  /// [isSports] - Optional filter for sports.
  ///
  /// [includePeople] - Optional filter whether to include people.
  ///
  /// [includeMedia] - Optional filter whether to include media.
  ///
  /// [includeGenres] - Optional filter whether to include genres.
  ///
  /// [includeStudios] - Optional filter whether to include studios.
  ///
  /// [includeArtists] - Optional filter whether to include artists.
  @GET('/Search/Hints')
  Future<SearchHintResult> getSearchHints({
    @Query('searchTerm') required String searchTerm,
    @Query('includePeople') bool? includePeople = true,
    @Query('includeMedia') bool? includeMedia = true,
    @Query('includeGenres') bool? includeGenres = true,
    @Query('includeStudios') bool? includeStudios = true,
    @Query('includeArtists') bool? includeArtists = true,
    @Query('startIndex') int? startIndex,
    @Query('limit') int? limit,
    @Query('userId') String? userId,
    @Query('includeItemTypes') List<BaseItemKind>? includeItemTypes,
    @Query('excludeItemTypes') List<BaseItemKind>? excludeItemTypes,
    @Query('mediaTypes') List<MediaType>? mediaTypes,
    @Query('parentId') String? parentId,
    @Query('isMovie') bool? isMovie,
    @Query('isSeries') bool? isSeries,
    @Query('isNews') bool? isNews,
    @Query('isKids') bool? isKids,
    @Query('isSports') bool? isSports,
  });
}
