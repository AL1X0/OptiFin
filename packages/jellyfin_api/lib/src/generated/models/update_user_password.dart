// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_user_password.g.dart';

/// The update user password request body.
@JsonSerializable()
class UpdateUserPassword {
  const UpdateUserPassword({
    this.currentPassword,
    this.currentPw,
    this.newPw,
    this.resetPassword,
  });
  
  factory UpdateUserPassword.fromJson(Map<String, Object?> json) => _$UpdateUserPasswordFromJson(json);
  
  /// Gets or sets the current sha1-hashed password.
  @JsonKey(name: 'CurrentPassword')
  final String? currentPassword;

  /// Gets or sets the current plain text password.
  @JsonKey(name: 'CurrentPw')
  final String? currentPw;

  /// Gets or sets the new plain text password.
  @JsonKey(name: 'NewPw')
  final String? newPw;

  /// Gets or sets a value indicating whether to reset the password.
  @JsonKey(name: 'ResetPassword')
  final bool? resetPassword;

  Map<String, Object?> toJson() => _$UpdateUserPasswordToJson(this);
}
