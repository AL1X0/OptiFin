// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'session_user_info.g.dart';

/// Class SessionUserInfo.
@JsonSerializable()
class SessionUserInfo {
  const SessionUserInfo({
    this.userId,
    this.userName,
  });
  
  factory SessionUserInfo.fromJson(Map<String, Object?> json) => _$SessionUserInfoFromJson(json);
  
  /// Gets or sets the user identifier.
  @JsonKey(name: 'UserId')
  final String? userId;

  /// Gets or sets the name of the user.
  @JsonKey(name: 'UserName')
  final String? userName;

  Map<String, Object?> toJson() => _$SessionUserInfoToJson(this);
}
