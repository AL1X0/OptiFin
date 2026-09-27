// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_system_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublicSystemInfo _$PublicSystemInfoFromJson(Map<String, dynamic> json) =>
    PublicSystemInfo(
      localAddress: json['LocalAddress'] as String?,
      serverName: json['ServerName'] as String?,
      version: json['Version'] as String?,
      productName: json['ProductName'] as String?,
      operatingSystem: json['OperatingSystem'] as String?,
      id: json['Id'] as String?,
      startupWizardCompleted: json['StartupWizardCompleted'] as bool?,
    );

Map<String, dynamic> _$PublicSystemInfoToJson(PublicSystemInfo instance) =>
    <String, dynamic>{
      'LocalAddress': instance.localAddress,
      'ServerName': instance.serverName,
      'Version': instance.version,
      'ProductName': instance.productName,
      'OperatingSystem': instance.operatingSystem,
      'Id': instance.id,
      'StartupWizardCompleted': instance.startupWizardCompleted,
    };
