// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/create_user_by_name.dart';
import '../models/update_user_password.dart';
import '../models/user_configuration.dart';
import '../models/user_dto.dart';
import '../models/user_policy.dart';

part 'user_client.g.dart';

@RestApi()
abstract class UserClient {
  factory UserClient(Dio dio, {String? baseUrl}) = _UserClient;

  /// Gets a list of users.
  ///
  /// [isHidden] - Optional filter by IsHidden=true or false.
  ///
  /// [isDisabled] - Optional filter by IsDisabled=true or false.
  @GET('/Users')
  Future<List<UserDto>> getUsers({
    @Query('isHidden') bool? isHidden,
    @Query('isDisabled') bool? isDisabled,
  });

  /// Updates a user.
  ///
  /// [userId] - The user id.
  ///
  /// [body] - Class UserDto.
  @POST('/Users')
  Future<void> updateUser({
    @Body() required UserDto body,
    @Query('userId') String? userId,
  });

  /// Gets a user by Id.
  ///
  /// [userId] - The user id.
  @GET('/Users/{userId}')
  Future<UserDto> getUserById({
    @Path('userId') required String userId,
  });

  /// Deletes a user.
  ///
  /// [userId] - The user id.
  @DELETE('/Users/{userId}')
  Future<void> deleteUser({
    @Path('userId') required String userId,
  });

  /// Updates a user policy.
  ///
  /// [userId] - The user id.
  @POST('/Users/{userId}/Policy')
  Future<void> updateUserPolicy({
    @Path('userId') required String userId,
    @Body() required UserPolicy body,
  });

  /// Updates a user configuration.
  ///
  /// [userId] - The user id.
  ///
  /// [body] - Class UserConfiguration.
  @POST('/Users/Configuration')
  Future<void> updateUserConfiguration({
    @Body() required UserConfiguration body,
    @Query('userId') String? userId,
  });

  /// Gets the user based on auth token.
  @GET('/Users/Me')
  Future<UserDto> getCurrentUser();

  /// Creates a user.
  ///
  /// [body] - The create user by name request body.
  @POST('/Users/New')
  Future<UserDto> createUserByName({
    @Body() required CreateUserByName body,
  });

  /// Updates a user's password.
  ///
  /// [userId] - The user id.
  ///
  /// [body] - The update user password request body.
  @POST('/Users/Password')
  Future<void> updateUserPassword({
    @Body() required UpdateUserPassword body,
    @Query('userId') String? userId,
  });

  /// Gets a list of publicly visible users for display on a login screen.
  @GET('/Users/Public')
  Future<List<UserDto>> getPublicUsers();
}
