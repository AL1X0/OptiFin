// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'forgot_password_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ForgotPasswordResult _$ForgotPasswordResultFromJson(
  Map<String, dynamic> json,
) => ForgotPasswordResult(
  action: json['Action'] == null
      ? null
      : ForgotPasswordResultAction.fromJson(json['Action']),
  pinFile: json['PinFile'] as String?,
  pinExpirationDate: json['PinExpirationDate'] == null
      ? null
      : DateTime.parse(json['PinExpirationDate'] as String),
);

Map<String, dynamic> _$ForgotPasswordResultToJson(
  ForgotPasswordResult instance,
) => <String, dynamic>{
  'Action': ?instance.action,
  'PinFile': ?instance.pinFile,
  'PinExpirationDate': ?instance.pinExpirationDate?.toIso8601String(),
};
