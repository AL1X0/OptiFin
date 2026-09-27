// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'media_segment_dto_type.dart';

part 'media_segment_dto.g.dart';

/// Api model for MediaSegment's.
@JsonSerializable()
class MediaSegmentDto {
  const MediaSegmentDto({
    required this.id,
    required this.itemId,
    required this.type,
    required this.startTicks,
    required this.endTicks,
  });
  
  factory MediaSegmentDto.fromJson(Map<String, Object?> json) => _$MediaSegmentDtoFromJson(json);
  
  /// Gets or sets the id of the media segment.
  @JsonKey(name: 'Id')
  final String id;

  /// Gets or sets the id of the associated item.
  @JsonKey(name: 'ItemId')
  final String itemId;

  /// Defines the types of content an individual Jellyfin.Database.Implementations.Entities.MediaSegment represents.
  @JsonKey(name: 'Type')
  final MediaSegmentDtoType type;

  /// Gets or sets the start of the segment.
  @JsonKey(name: 'StartTicks')
  final int startTicks;

  /// Gets or sets the end of the segment.
  @JsonKey(name: 'EndTicks')
  final int endTicks;

  Map<String, Object?> toJson() => _$MediaSegmentDtoToJson(this);
}
