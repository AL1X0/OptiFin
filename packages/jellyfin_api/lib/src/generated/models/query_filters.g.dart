// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'query_filters.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QueryFilters _$QueryFiltersFromJson(Map<String, dynamic> json) => QueryFilters(
  genres: (json['Genres'] as List<dynamic>?)
      ?.map((e) => NameGuidPair.fromJson(e as Map<String, dynamic>))
      .toList(),
  tags: (json['Tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
  audioLanguages: (json['AudioLanguages'] as List<dynamic>?)
      ?.map((e) => NameValuePair.fromJson(e as Map<String, dynamic>))
      .toList(),
  subtitleLanguages: (json['SubtitleLanguages'] as List<dynamic>?)
      ?.map((e) => NameValuePair.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$QueryFiltersToJson(QueryFilters instance) =>
    <String, dynamic>{
      'Genres': instance.genres,
      'Tags': instance.tags,
      'AudioLanguages': instance.audioLanguages,
      'SubtitleLanguages': instance.subtitleLanguages,
    };
