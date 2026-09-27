// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_user_by_name.g.dart';

/// The create user by name request body.
@JsonSerializable()
class CreateUserByName {
  const CreateUserByName({
    this.name,
    this.password,
  });
  
  factory CreateUserByName.fromJson(Map<String, Object?> json) => _$CreateUserByNameFromJson(json);
  
  /// Gets or sets the username.
  @JsonKey(name: 'Name')
  final String? name;

  /// Gets or sets the password.
  @JsonKey(name: 'Password')
  final String? password;

  Map<String, Object?> toJson() => _$CreateUserByNameToJson(this);
}
