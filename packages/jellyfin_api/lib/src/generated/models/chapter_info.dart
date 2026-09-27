// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'chapter_info.g.dart';

/// Class ChapterInfo.
@JsonSerializable()
class ChapterInfo {
  const ChapterInfo({
    this.startPositionTicks,
    this.name,
    this.imagePath,
    this.imageDateModified,
    this.imageTag,
  });
  
  factory ChapterInfo.fromJson(Map<String, Object?> json) => _$ChapterInfoFromJson(json);
  
  /// Gets or sets the start position ticks.
  @JsonKey(name: 'StartPositionTicks')
  final int? startPositionTicks;

  /// Gets or sets the name.
  @JsonKey(name: 'Name')
  final String? name;

  /// Gets or sets the image path.
  @JsonKey(name: 'ImagePath')
  final String? imagePath;
  @JsonKey(name: 'ImageDateModified')
  final DateTime? imageDateModified;
  @JsonKey(name: 'ImageTag')
  final String? imageTag;

  Map<String, Object?> toJson() => _$ChapterInfoToJson(this);
}
