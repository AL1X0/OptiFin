// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'forgot_password_pin_dto.g.dart';

/// Forgot Password Pin enter request body DTO.
@JsonSerializable()
class ForgotPasswordPinDto {
  const ForgotPasswordPinDto({
    required this.pin,
  });
  
  factory ForgotPasswordPinDto.fromJson(Map<String, Object?> json) => _$ForgotPasswordPinDtoFromJson(json);
  
  /// Gets or sets the entered pin to have the password reset.
  @JsonKey(name: 'Pin')
  final String pin;

  Map<String, Object?> toJson() => _$ForgotPasswordPinDtoToJson(this);
}
