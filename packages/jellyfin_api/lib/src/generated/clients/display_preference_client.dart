// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/display_preferences_dto.dart';

part 'display_preference_client.g.dart';

@RestApi()
abstract class DisplayPreferenceClient {
  factory DisplayPreferenceClient(Dio dio, {String? baseUrl}) = _DisplayPreferenceClient;

  /// Get Display Preferences.
  ///
  /// [displayPreferencesId] - Display preferences id.
  ///
  /// [userId] - User id.
  ///
  /// [client] - Client.
  @GET('/DisplayPreferences/{displayPreferencesId}')
  Future<DisplayPreferencesDto> getDisplayPreferences({
    @Path('displayPreferencesId') required String displayPreferencesId,
    @Query('client') required String client,
    @Query('userId') String? userId,
  });

  /// Update Display Preferences.
  ///
  /// [displayPreferencesId] - Display preferences id.
  ///
  /// [userId] - User Id.
  ///
  /// [client] - Client.
  ///
  /// [body] - Defines the display preferences for any item that supports them (usually Folders).
  @POST('/DisplayPreferences/{displayPreferencesId}')
  Future<void> updateDisplayPreferences({
    @Path('displayPreferencesId') required String displayPreferencesId,
    @Query('client') required String client,
    @Body() required DisplayPreferencesDto body,
    @Query('userId') String? userId,
  });
}
