// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_media_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ThemeMediaResult _$ThemeMediaResultFromJson(Map<String, dynamic> json) =>
    ThemeMediaResult(
      items: (json['Items'] as List<dynamic>?)
          ?.map((e) => BaseItemDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalRecordCount: (json['TotalRecordCount'] as num?)?.toInt(),
      startIndex: (json['StartIndex'] as num?)?.toInt(),
      ownerId: json['OwnerId'] as String?,
    );

Map<String, dynamic> _$ThemeMediaResultToJson(ThemeMediaResult instance) =>
    <String, dynamic>{
      'Items': instance.items,
      'TotalRecordCount': instance.totalRecordCount,
      'StartIndex': instance.startIndex,
      'OwnerId': instance.ownerId,
    };
