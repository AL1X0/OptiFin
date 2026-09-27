// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'seek_request_dto.g.dart';

/// Class SeekRequestDto.
@JsonSerializable()
class SeekRequestDto {
  const SeekRequestDto({
    this.positionTicks,
  });
  
  factory SeekRequestDto.fromJson(Map<String, Object?> json) => _$SeekRequestDtoFromJson(json);
  
  /// Gets or sets the position ticks.
  @JsonKey(name: 'PositionTicks')
  final int? positionTicks;

  Map<String, Object?> toJson() => _$SeekRequestDtoToJson(this);
}
