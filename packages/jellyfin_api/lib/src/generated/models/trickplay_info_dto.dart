// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'trickplay_info_dto.g.dart';

/// The trickplay api model.
@JsonSerializable()
class TrickplayInfoDto {
  const TrickplayInfoDto({
    this.width,
    this.height,
    this.tileWidth,
    this.tileHeight,
    this.thumbnailCount,
    this.interval,
    this.bandwidth,
  });
  
  factory TrickplayInfoDto.fromJson(Map<String, Object?> json) => _$TrickplayInfoDtoFromJson(json);
  
  /// Gets the width of an individual thumbnail.
  @JsonKey(name: 'Width')
  final int? width;

  /// Gets the height of an individual thumbnail.
  @JsonKey(name: 'Height')
  final int? height;

  /// Gets the amount of thumbnails per row.
  @JsonKey(name: 'TileWidth')
  final int? tileWidth;

  /// Gets the amount of thumbnails per column.
  @JsonKey(name: 'TileHeight')
  final int? tileHeight;

  /// Gets the total amount of non-black thumbnails.
  @JsonKey(name: 'ThumbnailCount')
  final int? thumbnailCount;

  /// Gets the interval in milliseconds between each trickplay thumbnail.
  @JsonKey(name: 'Interval')
  final int? interval;

  /// Gets the peak bandwidth usage in bits per second.
  @JsonKey(name: 'Bandwidth')
  final int? bandwidth;

  Map<String, Object?> toJson() => _$TrickplayInfoDtoToJson(this);
}
