// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chapter_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChapterInfo _$ChapterInfoFromJson(Map<String, dynamic> json) => ChapterInfo(
  startPositionTicks: (json['StartPositionTicks'] as num?)?.toInt(),
  name: json['Name'] as String?,
  imagePath: json['ImagePath'] as String?,
  imageDateModified: json['ImageDateModified'] == null
      ? null
      : DateTime.parse(json['ImageDateModified'] as String),
  imageTag: json['ImageTag'] as String?,
);

Map<String, dynamic> _$ChapterInfoToJson(ChapterInfo instance) =>
    <String, dynamic>{
      'StartPositionTicks': ?instance.startPositionTicks,
      'Name': ?instance.name,
      'ImagePath': ?instance.imagePath,
      'ImageDateModified': ?instance.imageDateModified?.toIso8601String(),
      'ImageTag': ?instance.imageTag,
    };
