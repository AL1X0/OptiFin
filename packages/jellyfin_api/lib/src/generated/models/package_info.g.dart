// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'package_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PackageInfo _$PackageInfoFromJson(Map<String, dynamic> json) => PackageInfo(
  name: json['name'] as String?,
  description: json['description'] as String?,
  overview: json['overview'] as String?,
  owner: json['owner'] as String?,
  category: json['category'] as String?,
  guid: json['guid'] as String?,
  versions: (json['versions'] as List<dynamic>?)
      ?.map((e) => VersionInfo.fromJson(e as Map<String, dynamic>))
      .toList(),
  imageUrl: json['imageUrl'] as String?,
);

Map<String, dynamic> _$PackageInfoToJson(PackageInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'overview': instance.overview,
      'owner': instance.owner,
      'category': instance.category,
      'guid': instance.guid,
      'versions': instance.versions,
      'imageUrl': instance.imageUrl,
    };
