// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'authentication_info.g.dart';

@JsonSerializable()
class AuthenticationInfo {
  const AuthenticationInfo({
    this.id,
    this.accessToken,
    this.deviceId,
    this.appName,
    this.appVersion,
    this.deviceName,
    this.userId,
    this.isActive,
    this.dateCreated,
    this.dateRevoked,
    this.dateLastActivity,
    this.userName,
  });
  
  factory AuthenticationInfo.fromJson(Map<String, Object?> json) => _$AuthenticationInfoFromJson(json);
  
  /// Gets or sets the identifier.
  @JsonKey(name: 'Id')
  final int? id;

  /// Gets or sets the access token.
  @JsonKey(name: 'AccessToken')
  final String? accessToken;

  /// Gets or sets the device identifier.
  @JsonKey(name: 'DeviceId')
  final String? deviceId;

  /// Gets or sets the name of the application.
  @JsonKey(name: 'AppName')
  final String? appName;

  /// Gets or sets the application version.
  @JsonKey(name: 'AppVersion')
  final String? appVersion;

  /// Gets or sets the name of the device.
  @JsonKey(name: 'DeviceName')
  final String? deviceName;

  /// Gets or sets the user identifier.
  @JsonKey(name: 'UserId')
  final String? userId;

  /// Gets or sets a value indicating whether this instance is active.
  @JsonKey(name: 'IsActive')
  final bool? isActive;

  /// Gets or sets the date created.
  @JsonKey(name: 'DateCreated')
  final DateTime? dateCreated;

  /// Gets or sets the date revoked.
  @JsonKey(name: 'DateRevoked')
  final DateTime? dateRevoked;
  @JsonKey(name: 'DateLastActivity')
  final DateTime? dateLastActivity;
  @JsonKey(name: 'UserName')
  final String? userName;

  Map<String, Object?> toJson() => _$AuthenticationInfoToJson(this);
}
