// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quick_connect_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QuickConnectResult _$QuickConnectResultFromJson(Map<String, dynamic> json) =>
    QuickConnectResult(
      authenticated: json['Authenticated'] as bool?,
      secret: json['Secret'] as String?,
      code: json['Code'] as String?,
      deviceId: json['DeviceId'] as String?,
      deviceName: json['DeviceName'] as String?,
      appName: json['AppName'] as String?,
      appVersion: json['AppVersion'] as String?,
      dateAdded: json['DateAdded'] == null
          ? null
          : DateTime.parse(json['DateAdded'] as String),
    );

Map<String, dynamic> _$QuickConnectResultToJson(QuickConnectResult instance) =>
    <String, dynamic>{
      'Authenticated': instance.authenticated,
      'Secret': instance.secret,
      'Code': instance.code,
      'DeviceId': instance.deviceId,
      'DeviceName': instance.deviceName,
      'AppName': instance.appName,
      'AppVersion': instance.appVersion,
      'DateAdded': instance.dateAdded?.toIso8601String(),
    };
