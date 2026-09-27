// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'forgot_password_dto.g.dart';

/// Forgot Password request body DTO.
@JsonSerializable()
class ForgotPasswordDto {
  const ForgotPasswordDto({
    required this.enteredUsername,
  });
  
  factory ForgotPasswordDto.fromJson(Map<String, Object?> json) => _$ForgotPasswordDtoFromJson(json);
  
  /// Gets or sets the entered username to have its password reset.
  @JsonKey(name: 'EnteredUsername')
  final String enteredUsername;

  Map<String, Object?> toJson() => _$ForgotPasswordDtoToJson(this);
}
