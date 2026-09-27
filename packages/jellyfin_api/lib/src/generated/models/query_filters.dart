// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'name_guid_pair.dart';
import 'name_value_pair.dart';

part 'query_filters.g.dart';

@JsonSerializable()
class QueryFilters {
  const QueryFilters({
    this.genres,
    this.tags,
    this.audioLanguages,
    this.subtitleLanguages,
  });
  
  factory QueryFilters.fromJson(Map<String, Object?> json) => _$QueryFiltersFromJson(json);
  
  @JsonKey(name: 'Genres')
  final List<NameGuidPair>? genres;
  @JsonKey(name: 'Tags')
  final List<String>? tags;
  @JsonKey(name: 'AudioLanguages')
  final List<NameValuePair>? audioLanguages;
  @JsonKey(name: 'SubtitleLanguages')
  final List<NameValuePair>? subtitleLanguages;

  Map<String, Object?> toJson() => _$QueryFiltersToJson(this);
}
