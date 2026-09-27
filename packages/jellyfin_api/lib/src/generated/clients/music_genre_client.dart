// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/base_item_dto.dart';

part 'music_genre_client.g.dart';

@RestApi()
abstract class MusicGenreClient {
  factory MusicGenreClient(Dio dio, {String? baseUrl}) = _MusicGenreClient;

  /// Gets a music genre, by name.
  ///
  /// [genreName] - The genre name.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  @Deprecated('This method is marked as deprecated')
  @GET('/MusicGenres/{genreName}')
  Future<BaseItemDto> getMusicGenre({
    @Path('genreName') required String genreName,
    @Query('userId') String? userId,
  });
}
