// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'timer_info_dto.dart';

part 'timer_info_dto_query_result.g.dart';

/// Query result container.
@JsonSerializable()
class TimerInfoDtoQueryResult {
  const TimerInfoDtoQueryResult({
    this.items,
    this.totalRecordCount,
    this.startIndex,
  });
  
  factory TimerInfoDtoQueryResult.fromJson(Map<String, Object?> json) => _$TimerInfoDtoQueryResultFromJson(json);
  
  /// Gets or sets the items.
  @JsonKey(name: 'Items')
  final List<TimerInfoDto>? items;

  /// Gets or sets the total number of records available.
  @JsonKey(name: 'TotalRecordCount')
  final int? totalRecordCount;

  /// Gets or sets the index of the first record in Items.
  @JsonKey(name: 'StartIndex')
  final int? startIndex;

  Map<String, Object?> toJson() => _$TimerInfoDtoQueryResultToJson(this);
}
