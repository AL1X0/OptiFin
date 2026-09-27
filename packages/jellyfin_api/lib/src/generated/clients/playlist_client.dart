// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/base_item_dto_query_result.dart';
import '../models/create_playlist_dto.dart';
import '../models/image_type.dart';
import '../models/item_fields.dart';
import '../models/media_type.dart';
import '../models/playlist_creation_result.dart';
import '../models/playlist_dto.dart';
import '../models/playlist_user_permissions.dart';
import '../models/update_playlist_dto.dart';
import '../models/update_playlist_user_dto.dart';

part 'playlist_client.g.dart';

@RestApi()
abstract class PlaylistClient {
  factory PlaylistClient(Dio dio, {String? baseUrl}) = _PlaylistClient;

  /// Creates a new playlist.
  ///
  /// For backwards compatibility parameters can be sent via Query or Body, with Query having higher precedence.
  /// Query parameters are obsolete.
  ///
  /// [name] - The playlist name.
  ///
  /// [ids] - The item ids.
  ///
  /// [userId] - The user id.
  ///
  /// [mediaType] - The media type.
  ///
  /// [body] - Create new playlist dto.
  @POST('/Playlists')
  Future<PlaylistCreationResult> createPlaylist({
    @Deprecated('This is marked as deprecated')
    @Query('name') String? name,
    @Deprecated('This is marked as deprecated')
    @Query('ids') List<String>? ids,
    @Deprecated('This is marked as deprecated')
    @Query('userId') String? userId,
    @Deprecated('This is marked as deprecated')
    @Query('mediaType') MediaType? mediaType,
    @Body() CreatePlaylistDto? body,
  });

  /// Updates a playlist.
  ///
  /// [playlistId] - The playlist id.
  ///
  /// [body] - Update existing playlist dto. Fields set to `null` will not be updated and keep their current values.
  @POST('/Playlists/{playlistId}')
  Future<void> updatePlaylist({
    @Path('playlistId') required String playlistId,
    @Body() required UpdatePlaylistDto body,
  });

  /// Get a playlist.
  ///
  /// [playlistId] - The playlist id.
  @GET('/Playlists/{playlistId}')
  Future<PlaylistDto> getPlaylist({
    @Path('playlistId') required String playlistId,
  });

  /// Adds items to a playlist.
  ///
  /// [playlistId] - The playlist id.
  ///
  /// [ids] - Item id, comma delimited.
  ///
  /// [position] - Optional. 0-based index where to place the items or at the end if `null`.
  ///
  /// [userId] - The userId.
  @POST('/Playlists/{playlistId}/Items')
  Future<void> addItemToPlaylist({
    @Path('playlistId') required String playlistId,
    @Query('ids') List<String>? ids,
    @Query('position') int? position,
    @Query('userId') String? userId,
  });

  /// Removes items from a playlist.
  ///
  /// [playlistId] - The playlist id.
  ///
  /// [entryIds] - The item ids, comma delimited.
  @DELETE('/Playlists/{playlistId}/Items')
  Future<void> removeItemFromPlaylist({
    @Path('playlistId') required String playlistId,
    @Query('entryIds') List<String>? entryIds,
  });

  /// Gets the original items of a playlist.
  ///
  /// [playlistId] - The playlist id.
  ///
  /// [userId] - User id.
  ///
  /// [startIndex] - Optional. The record index to start at. All items with a lower index will be dropped from the results.
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
  @GET('/Playlists/{playlistId}/Items')
  Future<BaseItemDtoQueryResult> getPlaylistItems({
    @Path('playlistId') required String playlistId,
    @Query('userId') String? userId,
    @Query('startIndex') int? startIndex,
    @Query('limit') int? limit,
    @Query('fields') List<ItemFields>? fields,
    @Query('enableImages') bool? enableImages,
    @Query('enableUserData') bool? enableUserData,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
  });

  /// Moves a playlist item.
  ///
  /// [playlistId] - The playlist id.
  ///
  /// [itemId] - The item id.
  ///
  /// [newIndex] - The new index.
  @POST('/Playlists/{playlistId}/Items/{itemId}/Move/{newIndex}')
  Future<void> moveItem({
    @Path('playlistId') required String playlistId,
    @Path('itemId') required String itemId,
    @Path('newIndex') required int newIndex,
  });

  /// Get a playlist's users.
  ///
  /// [playlistId] - The playlist id.
  @GET('/Playlists/{playlistId}/Users')
  Future<List<PlaylistUserPermissions>> getPlaylistUsers({
    @Path('playlistId') required String playlistId,
  });

  /// Get a playlist user.
  ///
  /// [playlistId] - The playlist id.
  ///
  /// [userId] - The user id.
  @GET('/Playlists/{playlistId}/Users/{userId}')
  Future<PlaylistUserPermissions> getPlaylistUser({
    @Path('playlistId') required String playlistId,
    @Path('userId') required String userId,
  });

  /// Modify a user of a playlist's users.
  ///
  /// [playlistId] - The playlist id.
  ///
  /// [userId] - The user id.
  ///
  /// [body] - Update existing playlist user dto. Fields set to `null` will not be updated and keep their current values.
  @POST('/Playlists/{playlistId}/Users/{userId}')
  Future<void> updatePlaylistUser({
    @Path('playlistId') required String playlistId,
    @Path('userId') required String userId,
    @Body() required UpdatePlaylistUserDto body,
  });

  /// Remove a user from a playlist's users.
  ///
  /// [playlistId] - The playlist id.
  ///
  /// [userId] - The user id.
  @DELETE('/Playlists/{playlistId}/Users/{userId}')
  Future<void> removeUserFromPlaylist({
    @Path('playlistId') required String playlistId,
    @Path('userId') required String userId,
  });
}
