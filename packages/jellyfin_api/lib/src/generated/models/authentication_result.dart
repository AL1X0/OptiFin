// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'session_info_dto.dart';
import 'user_dto.dart';

part 'authentication_result.g.dart';

/// A class representing an authentication result.
@JsonSerializable()
class AuthenticationResult {
  const AuthenticationResult({
    required this.user,
    required this.sessionInfo,
    required this.accessToken,
    required this.serverId,
  });
  
  factory AuthenticationResult.fromJson(Map<String, Object?> json) => _$AuthenticationResultFromJson(json);
  
  /// Class UserDto.
  @JsonKey(name: 'User')
  final UserDto? user;

  /// Session info DTO.
  @JsonKey(name: 'SessionInfo')
  final SessionInfoDto? sessionInfo;

  /// Gets or sets the access token.
  @JsonKey(name: 'AccessToken')
  final String? accessToken;

  /// Gets or sets the server id.
  @JsonKey(name: 'ServerId')
  final String? serverId;

  Map<String, Object?> toJson() => _$AuthenticationResultToJson(this);
}
