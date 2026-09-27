// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'query_filters_legacy.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QueryFiltersLegacy _$QueryFiltersLegacyFromJson(Map<String, dynamic> json) =>
    QueryFiltersLegacy(
      genres: (json['Genres'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      tags: (json['Tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      officialRatings: (json['OfficialRatings'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      years: (json['Years'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
    );

Map<String, dynamic> _$QueryFiltersLegacyToJson(QueryFiltersLegacy instance) =>
    <String, dynamic>{
      'Genres': ?instance.genres,
      'Tags': ?instance.tags,
      'OfficialRatings': ?instance.officialRatings,
      'Years': ?instance.years,
    };
