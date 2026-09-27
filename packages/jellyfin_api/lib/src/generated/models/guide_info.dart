// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'guide_info.g.dart';

@JsonSerializable()
class GuideInfo {
  const GuideInfo({
    this.startDate,
    this.endDate,
  });
  
  factory GuideInfo.fromJson(Map<String, Object?> json) => _$GuideInfoFromJson(json);
  
  /// Gets or sets the start date.
  @JsonKey(name: 'StartDate')
  final DateTime? startDate;

  /// Gets or sets the end date.
  @JsonKey(name: 'EndDate')
  final DateTime? endDate;

  Map<String, Object?> toJson() => _$GuideInfoToJson(this);
}
