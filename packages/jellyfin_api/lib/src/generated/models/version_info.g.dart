// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'version_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VersionInfo _$VersionInfoFromJson(Map<String, dynamic> json) => VersionInfo(
  version: json['version'] as String?,
  versionNumber: json['VersionNumber'] as String?,
  changelog: json['changelog'] as String?,
  targetAbi: json['targetAbi'] as String?,
  sourceUrl: json['sourceUrl'] as String?,
  checksum: json['checksum'] as String?,
  timestamp: json['timestamp'] as String?,
  repositoryName: json['repositoryName'] as String?,
  repositoryUrl: json['repositoryUrl'] as String?,
);

Map<String, dynamic> _$VersionInfoToJson(VersionInfo instance) =>
    <String, dynamic>{
      'version': instance.version,
      'VersionNumber': instance.versionNumber,
      'changelog': instance.changelog,
      'targetAbi': instance.targetAbi,
      'sourceUrl': instance.sourceUrl,
      'checksum': instance.checksum,
      'timestamp': instance.timestamp,
      'repositoryName': instance.repositoryName,
      'repositoryUrl': instance.repositoryUrl,
    };
