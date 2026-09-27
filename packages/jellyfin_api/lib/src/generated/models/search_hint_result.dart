// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'search_hint.dart';

part 'search_hint_result.g.dart';

/// Class SearchHintResult.
@JsonSerializable()
class SearchHintResult {
  const SearchHintResult({
    this.searchHints,
    this.totalRecordCount,
  });
  
  factory SearchHintResult.fromJson(Map<String, Object?> json) => _$SearchHintResultFromJson(json);
  
  /// Gets the search hints.
  @JsonKey(name: 'SearchHints')
  final List<SearchHint>? searchHints;

  /// Gets the total record count.
  @JsonKey(name: 'TotalRecordCount')
  final int? totalRecordCount;

  Map<String, Object?> toJson() => _$SearchHintResultToJson(this);
}
