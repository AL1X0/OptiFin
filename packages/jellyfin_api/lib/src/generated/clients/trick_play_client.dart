// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'trick_play_client.g.dart';

@RestApi()
abstract class TrickPlayClient {
  factory TrickPlayClient(Dio dio, {String? baseUrl}) = _TrickPlayClient;

  /// Gets a trickplay tile image.
  ///
  /// [itemId] - The item id.
  ///
  /// [width] - The width of a single tile.
  ///
  /// [index] - The index of the desired tile.
  ///
  /// [mediaSourceId] - The media version id, if using an alternate version.
  @GET('/Videos/{itemId}/Trickplay/{width}/{index}.jpg')
  @DioResponseType(ResponseType.stream)
  Stream<String> getTrickplayTileImage({
    @Path('itemId') required String itemId,
    @Path('width') required int width,
    @Path('index') required int index,
    @Query('mediaSourceId') String? mediaSourceId,
  });

  /// Gets an image tiles playlist for trickplay.
  ///
  /// [itemId] - The item id.
  ///
  /// [width] - The width of a single tile.
  ///
  /// [mediaSourceId] - The media version id, if using an alternate version.
  @GET('/Videos/{itemId}/Trickplay/{width}/tiles.m3u8')
  @DioResponseType(ResponseType.stream)
  Stream<String> getTrickplayHlsPlaylist({
    @Path('itemId') required String itemId,
    @Path('width') required int width,
    @Query('mediaSourceId') String? mediaSourceId,
  });
}
