// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'play_request_dto.g.dart';

/// Class PlayRequestDto.
@JsonSerializable()
class PlayRequestDto {
  const PlayRequestDto({
    this.playingQueue,
    this.playingItemPosition,
    this.startPositionTicks,
  });
  
  factory PlayRequestDto.fromJson(Map<String, Object?> json) => _$PlayRequestDtoFromJson(json);
  
  /// Gets or sets the playing queue.
  @JsonKey(name: 'PlayingQueue')
  final List<String>? playingQueue;

  /// Gets or sets the position of the playing item in the queue.
  @JsonKey(name: 'PlayingItemPosition')
  final int? playingItemPosition;

  /// Gets or sets the start position ticks.
  @JsonKey(name: 'StartPositionTicks')
  final int? startPositionTicks;

  Map<String, Object?> toJson() => _$PlayRequestDtoToJson(this);
}
