// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'authenticate_user_by_name.g.dart';

/// The authenticate user by name request body.
@JsonSerializable()
class AuthenticateUserByName {
  const AuthenticateUserByName({
    this.username,
    this.pw,
  });
  
  factory AuthenticateUserByName.fromJson(Map<String, Object?> json) => _$AuthenticateUserByNameFromJson(json);
  
  /// Gets or sets the username.
  @JsonKey(name: 'Username')
  final String? username;

  /// Gets or sets the plain text password.
  @JsonKey(name: 'Pw')
  final String? pw;

  Map<String, Object?> toJson() => _$AuthenticateUserByNameToJson(this);
}
