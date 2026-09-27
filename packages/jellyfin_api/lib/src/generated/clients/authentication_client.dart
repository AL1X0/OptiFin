// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/authenticate_user_by_name.dart';
import '../models/authentication_info_query_result.dart';
import '../models/authentication_result.dart';
import '../models/forgot_password_dto.dart';
import '../models/forgot_password_pin_dto.dart';
import '../models/forgot_password_result.dart';
import '../models/name_id_pair.dart';
import '../models/pin_redeem_result.dart';
import '../models/quick_connect_dto.dart';
import '../models/quick_connect_result.dart';

part 'authentication_client.g.dart';

@RestApi()
abstract class AuthenticationClient {
  factory AuthenticationClient(Dio dio, {String? baseUrl}) = _AuthenticationClient;

  /// Get all keys.
  @GET('/Auth/Keys')
  Future<AuthenticationInfoQueryResult> getKeys();

  /// Create a new api key.
  ///
  /// [app] - Name of the app using the authentication key.
  @POST('/Auth/Keys')
  Future<void> createKey({
    @Query('app') required String app,
  });

  /// Remove an api key.
  ///
  /// [key] - The access token to delete.
  @DELETE('/Auth/Keys/{key}')
  Future<void> revokeKey({
    @Path('key') required String key,
  });

  /// Authorizes a pending quick connect request.
  ///
  /// [code] - Quick connect code to authorize.
  ///
  /// [userId] - The user the authorize. Access to the requested user is required.
  @POST('/QuickConnect/Authorize')
  Future<bool> authorizeQuickConnect({
    @Query('code') required String code,
    @Query('userId') String? userId,
  });

  /// Attempts to retrieve authentication information.
  ///
  /// [secret] - Secret previously returned from the Initiate endpoint.
  @GET('/QuickConnect/Connect')
  Future<QuickConnectResult> getQuickConnectState({
    @Query('secret') required String secret,
  });

  /// Gets the current quick connect state.
  @GET('/QuickConnect/Enabled')
  Future<bool> getQuickConnectEnabled();

  /// Initiate a new quick connect request.
  @POST('/QuickConnect/Initiate')
  Future<QuickConnectResult> initiateQuickConnect();

  /// Get all password reset providers.
  @GET('/Auth/PasswordResetProviders')
  Future<List<NameIdPair>> getPasswordResetProviders();

  /// Get all auth providers.
  @GET('/Auth/Providers')
  Future<List<NameIdPair>> getAuthProviders();

  /// Authenticates a user by name.
  ///
  /// [body] - The authenticate user by name request body.
  @POST('/Users/AuthenticateByName')
  Future<AuthenticationResult> authenticateUserByName({
    @Body() required AuthenticateUserByName body,
  });

  /// Authenticates a user with quick connect.
  ///
  /// [body] - The quick connect request body.
  @POST('/Users/AuthenticateWithQuickConnect')
  Future<AuthenticationResult> authenticateWithQuickConnect({
    @Body() required QuickConnectDto body,
  });

  /// Initiates the forgot password process for a local user.
  ///
  /// [body] - Forgot Password request body DTO.
  @POST('/Users/ForgotPassword')
  Future<ForgotPasswordResult> forgotPassword({
    @Body() required ForgotPasswordDto body,
  });

  /// Redeems a forgot password pin.
  ///
  /// [body] - Forgot Password Pin enter request body DTO.
  @POST('/Users/ForgotPassword/Pin')
  Future<PinRedeemResult> forgotPasswordPin({
    @Body() required ForgotPasswordPinDto body,
  });
}
