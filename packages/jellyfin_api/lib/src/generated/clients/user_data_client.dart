// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/update_user_item_data_dto.dart';
import '../models/user_item_data_dto.dart';

part 'user_data_client.g.dart';

@RestApi()
abstract class UserDataClient {
  factory UserDataClient(Dio dio, {String? baseUrl}) = _UserDataClient;

  /// Get Item User Data.
  ///
  /// [userId] - The user id.
  ///
  /// [itemId] - The item id.
  @GET('/UserItems/{itemId}/UserData')
  Future<UserItemDataDto> getItemUserData({
    @Path('itemId') required String itemId,
    @Query('userId') String? userId,
  });

  /// Update Item User Data.
  ///
  /// [userId] - The user id.
  ///
  /// [itemId] - The item id.
  ///
  /// [body] - This is used by the api to get information about a item user data.
  @POST('/UserItems/{itemId}/UserData')
  Future<UserItemDataDto> updateItemUserData({
    @Path('itemId') required String itemId,
    @Body() required UpdateUserItemDataDto body,
    @Query('userId') String? userId,
  });

  /// Marks an item as played for user.
  ///
  /// [userId] - User id.
  ///
  /// [itemId] - Item id.
  ///
  /// [datePlayed] - Optional. The date the item was played.
  @POST('/UserPlayedItems/{itemId}')
  Future<UserItemDataDto> markPlayedItem({
    @Path('itemId') required String itemId,
    @Query('userId') String? userId,
    @Query('datePlayed') DateTime? datePlayed,
  });

  /// Marks an item as unplayed for user.
  ///
  /// [userId] - User id.
  ///
  /// [itemId] - Item id.
  @DELETE('/UserPlayedItems/{itemId}')
  Future<UserItemDataDto> markUnplayedItem({
    @Path('itemId') required String itemId,
    @Query('userId') String? userId,
  });

  /// Marks an item as a favorite.
  ///
  /// [userId] - User id.
  ///
  /// [itemId] - Item id.
  @POST('/UserFavoriteItems/{itemId}')
  Future<UserItemDataDto> markFavoriteItem({
    @Path('itemId') required String itemId,
    @Query('userId') String? userId,
  });

  /// Unmarks item as a favorite.
  ///
  /// [userId] - User id.
  ///
  /// [itemId] - Item id.
  @DELETE('/UserFavoriteItems/{itemId}')
  Future<UserItemDataDto> unmarkFavoriteItem({
    @Path('itemId') required String itemId,
    @Query('userId') String? userId,
  });

  /// Deletes a user's saved personal rating for an item.
  ///
  /// [userId] - User id.
  ///
  /// [itemId] - Item id.
  @DELETE('/UserItems/{itemId}/Rating')
  Future<UserItemDataDto> deleteUserItemRating({
    @Path('itemId') required String itemId,
    @Query('userId') String? userId,
  });

  /// Updates a user's rating for an item.
  ///
  /// [userId] - User id.
  ///
  /// [itemId] - Item id.
  ///
  /// [likes] - Whether this M:Jellyfin.Api.Controllers.UserLibraryController.UpdateUserItemRating(System.Nullable{System.Guid},System.Guid,System.Nullable{System.Boolean}) is likes.
  @POST('/UserItems/{itemId}/Rating')
  Future<UserItemDataDto> updateUserItemRating({
    @Path('itemId') required String itemId,
    @Query('userId') String? userId,
    @Query('likes') bool? likes,
  });
}
