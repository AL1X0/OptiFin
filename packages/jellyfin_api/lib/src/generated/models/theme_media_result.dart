// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'base_item_dto.dart';

part 'theme_media_result.g.dart';

/// Class ThemeMediaResult.
@JsonSerializable()
class ThemeMediaResult {
  const ThemeMediaResult({
    this.items,
    this.totalRecordCount,
    this.startIndex,
    this.ownerId,
  });
  
  factory ThemeMediaResult.fromJson(Map<String, Object?> json) => _$ThemeMediaResultFromJson(json);
  
  /// Gets or sets the items.
  @JsonKey(name: 'Items')
  final List<BaseItemDto>? items;

  /// Gets or sets the total number of records available.
  @JsonKey(name: 'TotalRecordCount')
  final int? totalRecordCount;

  /// Gets or sets the index of the first record in Items.
  @JsonKey(name: 'StartIndex')
  final int? startIndex;

  /// Gets or sets the owner id.
  @JsonKey(name: 'OwnerId')
  final String? ownerId;

  Map<String, Object?> toJson() => _$ThemeMediaResultToJson(this);
}
