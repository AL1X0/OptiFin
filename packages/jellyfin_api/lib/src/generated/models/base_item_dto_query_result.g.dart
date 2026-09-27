// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'base_item_dto_query_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BaseItemDtoQueryResult _$BaseItemDtoQueryResultFromJson(
  Map<String, dynamic> json,
) => BaseItemDtoQueryResult(
  items: (json['Items'] as List<dynamic>?)
      ?.map((e) => BaseItemDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalRecordCount: (json['TotalRecordCount'] as num?)?.toInt(),
  startIndex: (json['StartIndex'] as num?)?.toInt(),
);

Map<String, dynamic> _$BaseItemDtoQueryResultToJson(
  BaseItemDtoQueryResult instance,
) => <String, dynamic>{
  'Items': ?instance.items,
  'TotalRecordCount': ?instance.totalRecordCount,
  'StartIndex': ?instance.startIndex,
};
