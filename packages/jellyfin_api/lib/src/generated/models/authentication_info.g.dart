// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'authentication_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthenticationInfo _$AuthenticationInfoFromJson(Map<String, dynamic> json) =>
    AuthenticationInfo(
      id: (json['Id'] as num?)?.toInt(),
      accessToken: json['AccessToken'] as String?,
      deviceId: json['DeviceId'] as String?,
      appName: json['AppName'] as String?,
      appVersion: json['AppVersion'] as String?,
      deviceName: json['DeviceName'] as String?,
      userId: json['UserId'] as String?,
      isActive: json['IsActive'] as bool?,
      dateCreated: json['DateCreated'] == null
          ? null
          : DateTime.parse(json['DateCreated'] as String),
      dateRevoked: json['DateRevoked'] == null
          ? null
          : DateTime.parse(json['DateRevoked'] as String),
      dateLastActivity: json['DateLastActivity'] == null
          ? null
          : DateTime.parse(json['DateLastActivity'] as String),
      userName: json['UserName'] as String?,
    );

Map<String, dynamic> _$AuthenticationInfoToJson(AuthenticationInfo instance) =>
    <String, dynamic>{
      'Id': instance.id,
      'AccessToken': instance.accessToken,
      'DeviceId': instance.deviceId,
      'AppName': instance.appName,
      'AppVersion': instance.appVersion,
      'DeviceName': instance.deviceName,
      'UserId': instance.userId,
      'IsActive': instance.isActive,
      'DateCreated': instance.dateCreated?.toIso8601String(),
      'DateRevoked': instance.dateRevoked?.toIso8601String(),
      'DateLastActivity': instance.dateLastActivity?.toIso8601String(),
      'UserName': instance.userName,
    };
