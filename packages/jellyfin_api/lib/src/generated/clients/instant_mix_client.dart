// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/base_item_dto_query_result.dart';
import '../models/image_type.dart';
import '../models/item_fields.dart';

part 'instant_mix_client.g.dart';

@RestApi()
abstract class InstantMixClient {
  factory InstantMixClient(Dio dio, {String? baseUrl}) = _InstantMixClient;

  /// Creates an instant playlist based on a given album.
  ///
  /// [itemId] - The item id.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output.
  ///
  /// [enableImages] - Optional. Include image information in output.
  ///
  /// [enableUserData] - Optional. Include user data.
  ///
  /// [imageTypeLimit] - Optional. The max number of images to return, per image type.
  ///
  /// [enableImageTypes] - Optional. The image types to include in the output.
  @GET('/Albums/{itemId}/InstantMix')
  Future<BaseItemDtoQueryResult> getInstantMixFromAlbum({
    @Path('itemId') required String itemId,
    @Query('userId') String? userId,
    @Query('limit') int? limit,
    @Query('fields') List<ItemFields>? fields,
    @Query('enableImages') bool? enableImages,
    @Query('enableUserData') bool? enableUserData,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
  });

  /// Creates an instant playlist based on a given artist.
  ///
  /// [itemId] - The item id.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output.
  ///
  /// [enableImages] - Optional. Include image information in output.
  ///
  /// [enableUserData] - Optional. Include user data.
  ///
  /// [imageTypeLimit] - Optional. The max number of images to return, per image type.
  ///
  /// [enableImageTypes] - Optional. The image types to include in the output.
  @GET('/Artists/{itemId}/InstantMix')
  Future<BaseItemDtoQueryResult> getInstantMixFromArtists({
    @Path('itemId') required String itemId,
    @Query('userId') String? userId,
    @Query('limit') int? limit,
    @Query('fields') List<ItemFields>? fields,
    @Query('enableImages') bool? enableImages,
    @Query('enableUserData') bool? enableUserData,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
  });

  /// Creates an instant playlist based on a given item.
  ///
  /// [itemId] - The item id.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output.
  ///
  /// [enableImages] - Optional. Include image information in output.
  ///
  /// [enableUserData] - Optional. Include user data.
  ///
  /// [imageTypeLimit] - Optional. The max number of images to return, per image type.
  ///
  /// [enableImageTypes] - Optional. The image types to include in the output.
  @GET('/Items/{itemId}/InstantMix')
  Future<BaseItemDtoQueryResult> getInstantMixFromItem({
    @Path('itemId') required String itemId,
    @Query('userId') String? userId,
    @Query('limit') int? limit,
    @Query('fields') List<ItemFields>? fields,
    @Query('enableImages') bool? enableImages,
    @Query('enableUserData') bool? enableUserData,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
  });

  /// Creates an instant playlist based on a given genre.
  ///
  /// [name] - The genre name.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output.
  ///
  /// [enableImages] - Optional. Include image information in output.
  ///
  /// [enableUserData] - Optional. Include user data.
  ///
  /// [imageTypeLimit] - Optional. The max number of images to return, per image type.
  ///
  /// [enableImageTypes] - Optional. The image types to include in the output.
  @Deprecated('This method is marked as deprecated')
  @GET('/MusicGenres/{name}/InstantMix')
  Future<BaseItemDtoQueryResult> getInstantMixFromMusicGenreByName({
    @Path('name') required String name,
    @Query('userId') String? userId,
    @Query('limit') int? limit,
    @Query('fields') List<ItemFields>? fields,
    @Query('enableImages') bool? enableImages,
    @Query('enableUserData') bool? enableUserData,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
  });

  /// Creates an instant playlist based on a given genre.
  ///
  /// [id] - The item id.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output.
  ///
  /// [enableImages] - Optional. Include image information in output.
  ///
  /// [enableUserData] - Optional. Include user data.
  ///
  /// [imageTypeLimit] - Optional. The max number of images to return, per image type.
  ///
  /// [enableImageTypes] - Optional. The image types to include in the output.
  @Deprecated('This method is marked as deprecated')
  @GET('/MusicGenres/InstantMix')
  Future<BaseItemDtoQueryResult> getInstantMixFromMusicGenreById({
    @Query('id') required String id,
    @Query('userId') String? userId,
    @Query('limit') int? limit,
    @Query('fields') List<ItemFields>? fields,
    @Query('enableImages') bool? enableImages,
    @Query('enableUserData') bool? enableUserData,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
  });

  /// Creates an instant playlist based on a given playlist.
  ///
  /// [itemId] - The item id.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output.
  ///
  /// [enableImages] - Optional. Include image information in output.
  ///
  /// [enableUserData] - Optional. Include user data.
  ///
  /// [imageTypeLimit] - Optional. The max number of images to return, per image type.
  ///
  /// [enableImageTypes] - Optional. The image types to include in the output.
  @GET('/Playlists/{itemId}/InstantMix')
  Future<BaseItemDtoQueryResult> getInstantMixFromPlaylist({
    @Path('itemId') required String itemId,
    @Query('userId') String? userId,
    @Query('limit') int? limit,
    @Query('fields') List<ItemFields>? fields,
    @Query('enableImages') bool? enableImages,
    @Query('enableUserData') bool? enableUserData,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
  });

  /// Creates an instant playlist based on a given song.
  ///
  /// [itemId] - The item id.
  ///
  /// [userId] - Optional. Filter by user id, and attach user data.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output.
  ///
  /// [enableImages] - Optional. Include image information in output.
  ///
  /// [enableUserData] - Optional. Include user data.
  ///
  /// [imageTypeLimit] - Optional. The max number of images to return, per image type.
  ///
  /// [enableImageTypes] - Optional. The image types to include in the output.
  @GET('/Songs/{itemId}/InstantMix')
  Future<BaseItemDtoQueryResult> getInstantMixFromSong({
    @Path('itemId') required String itemId,
    @Query('userId') String? userId,
    @Query('limit') int? limit,
    @Query('fields') List<ItemFields>? fields,
    @Query('enableImages') bool? enableImages,
    @Query('enableUserData') bool? enableUserData,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
  });
}
