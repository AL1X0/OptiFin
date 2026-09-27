// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'user_configuration.dart';
import 'user_policy.dart';

part 'user_dto.g.dart';

/// Class UserDto.
@JsonSerializable()
class UserDto {
  const UserDto({
    required this.name,
    required this.serverId,
    required this.serverName,
    required this.id,
    required this.primaryImageTag,
    required this.hasPassword,
    required this.hasConfiguredPassword,
    required this.hasConfiguredEasyPassword,
    required this.enableAutoLogin,
    required this.lastLoginDate,
    required this.lastActivityDate,
    required this.configuration,
    required this.policy,
    required this.primaryImageAspectRatio,
  });
  
  factory UserDto.fromJson(Map<String, Object?> json) => _$UserDtoFromJson(json);
  
  /// Gets or sets the name.
  @JsonKey(name: 'Name')
  final String? name;

  /// Gets or sets the server identifier.
  @JsonKey(name: 'ServerId')
  final String? serverId;

  /// Gets or sets the name of the server.
  /// This is not used by the server and is for client-side usage only.
  @JsonKey(name: 'ServerName')
  final String? serverName;

  /// Gets or sets the id.
  @JsonKey(name: 'Id')
  final String id;

  /// Gets or sets the primary image tag.
  @JsonKey(name: 'PrimaryImageTag')
  final String? primaryImageTag;

  /// Gets or sets a value indicating whether this instance has password.
  @JsonKey(name: 'HasPassword')
  final bool? hasPassword;

  /// Gets or sets a value indicating whether this instance has configured password.
  @JsonKey(name: 'HasConfiguredPassword')
  final bool? hasConfiguredPassword;

  /// Gets or sets a value indicating whether this instance has configured easy password.
  @JsonKey(name: 'HasConfiguredEasyPassword')
  final bool? hasConfiguredEasyPassword;

  /// Gets or sets whether async login is enabled or not.
  @JsonKey(name: 'EnableAutoLogin')
  final bool? enableAutoLogin;

  /// Gets or sets the last login date.
  @JsonKey(name: 'LastLoginDate')
  final DateTime? lastLoginDate;

  /// Gets or sets the last activity date.
  @JsonKey(name: 'LastActivityDate')
  final DateTime? lastActivityDate;

  /// Gets or sets the configuration.
  @JsonKey(name: 'Configuration')
  final UserConfiguration? configuration;

  /// Gets or sets the policy.
  @JsonKey(name: 'Policy')
  final UserPolicy? policy;

  /// Gets or sets the primary image aspect ratio.
  @JsonKey(name: 'PrimaryImageAspectRatio')
  final double? primaryImageAspectRatio;

  Map<String, Object?> toJson() => _$UserDtoToJson(this);
}
