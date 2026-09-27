// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'forgot_password_result_action.dart';

part 'forgot_password_result.g.dart';

@JsonSerializable()
class ForgotPasswordResult {
  const ForgotPasswordResult({
    required this.action,
    required this.pinFile,
    required this.pinExpirationDate,
  });
  
  factory ForgotPasswordResult.fromJson(Map<String, Object?> json) => _$ForgotPasswordResultFromJson(json);
  
  /// Gets or sets the action.
  @JsonKey(name: 'Action')
  final ForgotPasswordResultAction action;

  /// Gets or sets the pin file.
  @JsonKey(name: 'PinFile')
  final String? pinFile;

  /// Gets or sets the pin expiration date.
  @JsonKey(name: 'PinExpirationDate')
  final DateTime? pinExpirationDate;

  Map<String, Object?> toJson() => _$ForgotPasswordResultToJson(this);
}
