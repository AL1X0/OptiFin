// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_hint_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SearchHintResult _$SearchHintResultFromJson(Map<String, dynamic> json) =>
    SearchHintResult(
      searchHints: (json['SearchHints'] as List<dynamic>?)
          ?.map((e) => SearchHint.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalRecordCount: (json['TotalRecordCount'] as num?)?.toInt(),
    );

Map<String, dynamic> _$SearchHintResultToJson(SearchHintResult instance) =>
    <String, dynamic>{
      'SearchHints': ?instance.searchHints,
      'TotalRecordCount': ?instance.totalRecordCount,
    };
