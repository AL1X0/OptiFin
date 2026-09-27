// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_log_entry_query_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActivityLogEntryQueryResult _$ActivityLogEntryQueryResultFromJson(
  Map<String, dynamic> json,
) => ActivityLogEntryQueryResult(
  items: (json['Items'] as List<dynamic>?)
      ?.map((e) => ActivityLogEntry.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalRecordCount: (json['TotalRecordCount'] as num?)?.toInt(),
  startIndex: (json['StartIndex'] as num?)?.toInt(),
);

Map<String, dynamic> _$ActivityLogEntryQueryResultToJson(
  ActivityLogEntryQueryResult instance,
) => <String, dynamic>{
  'Items': instance.items,
  'TotalRecordCount': instance.totalRecordCount,
  'StartIndex': instance.startIndex,
};
