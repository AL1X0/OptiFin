// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installation_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InstallationInfo _$InstallationInfoFromJson(Map<String, dynamic> json) =>
    InstallationInfo(
      guid: json['Guid'] as String,
      name: json['Name'] as String?,
      version: json['Version'] as String?,
      changelog: json['Changelog'] as String?,
      sourceUrl: json['SourceUrl'] as String?,
      checksum: json['Checksum'] as String?,
      packageInfo: json['PackageInfo'] == null
          ? null
          : PackageInfo.fromJson(json['PackageInfo'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$InstallationInfoToJson(InstallationInfo instance) =>
    <String, dynamic>{
      'Guid': instance.guid,
      'Name': instance.name,
      'Version': instance.version,
      'Changelog': instance.changelog,
      'SourceUrl': instance.sourceUrl,
      'Checksum': instance.checksum,
      'PackageInfo': instance.packageInfo,
    };
