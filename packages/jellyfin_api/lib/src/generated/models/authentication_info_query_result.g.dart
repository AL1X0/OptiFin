// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'authentication_info_query_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthenticationInfoQueryResult _$AuthenticationInfoQueryResultFromJson(
  Map<String, dynamic> json,
) => AuthenticationInfoQueryResult(
  items: (json['Items'] as List<dynamic>?)
      ?.map((e) => AuthenticationInfo.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalRecordCount: (json['TotalRecordCount'] as num?)?.toInt(),
  startIndex: (json['StartIndex'] as num?)?.toInt(),
);

Map<String, dynamic> _$AuthenticationInfoQueryResultToJson(
  AuthenticationInfoQueryResult instance,
) => <String, dynamic>{
  'Items': instance.items,
  'TotalRecordCount': instance.totalRecordCount,
  'StartIndex': instance.startIndex,
};
