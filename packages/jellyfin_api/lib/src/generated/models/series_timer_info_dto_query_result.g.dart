// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'series_timer_info_dto_query_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SeriesTimerInfoDtoQueryResult _$SeriesTimerInfoDtoQueryResultFromJson(
  Map<String, dynamic> json,
) => SeriesTimerInfoDtoQueryResult(
  items: (json['Items'] as List<dynamic>?)
      ?.map((e) => SeriesTimerInfoDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalRecordCount: (json['TotalRecordCount'] as num?)?.toInt(),
  startIndex: (json['StartIndex'] as num?)?.toInt(),
);

Map<String, dynamic> _$SeriesTimerInfoDtoQueryResultToJson(
  SeriesTimerInfoDtoQueryResult instance,
) => <String, dynamic>{
  'Items': ?instance.items,
  'TotalRecordCount': ?instance.totalRecordCount,
  'StartIndex': ?instance.startIndex,
};
