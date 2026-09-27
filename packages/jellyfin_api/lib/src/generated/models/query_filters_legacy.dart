// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'query_filters_legacy.g.dart';

@JsonSerializable()
class QueryFiltersLegacy {
  const QueryFiltersLegacy({
    this.genres,
    this.tags,
    this.officialRatings,
    this.years,
  });
  
  factory QueryFiltersLegacy.fromJson(Map<String, Object?> json) => _$QueryFiltersLegacyFromJson(json);
  
  @JsonKey(name: 'Genres')
  final List<String>? genres;
  @JsonKey(name: 'Tags')
  final List<String>? tags;
  @JsonKey(name: 'OfficialRatings')
  final List<String>? officialRatings;
  @JsonKey(name: 'Years')
  final List<int>? years;

  Map<String, Object?> toJson() => _$QueryFiltersLegacyToJson(this);
}
