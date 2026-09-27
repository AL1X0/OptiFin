// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'authentication_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthenticationResult _$AuthenticationResultFromJson(
  Map<String, dynamic> json,
) => AuthenticationResult(
  user: json['User'] == null
      ? null
      : UserDto.fromJson(json['User'] as Map<String, dynamic>),
  sessionInfo: json['SessionInfo'] == null
      ? null
      : SessionInfoDto.fromJson(json['SessionInfo'] as Map<String, dynamic>),
  accessToken: json['AccessToken'] as String?,
  serverId: json['ServerId'] as String?,
);

Map<String, dynamic> _$AuthenticationResultToJson(
  AuthenticationResult instance,
) => <String, dynamic>{
  'User': ?instance.user,
  'SessionInfo': ?instance.sessionInfo,
  'AccessToken': ?instance.accessToken,
  'ServerId': ?instance.serverId,
};
