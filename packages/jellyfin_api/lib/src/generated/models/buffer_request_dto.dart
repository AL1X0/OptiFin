// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'buffer_request_dto.g.dart';

/// Class BufferRequestDto.
@JsonSerializable()
class BufferRequestDto {
  const BufferRequestDto({
    this.whenValue,
    this.positionTicks,
    this.isPlaying,
    this.playlistItemId,
  });
  
  factory BufferRequestDto.fromJson(Map<String, Object?> json) => _$BufferRequestDtoFromJson(json);
  
  /// Gets or sets when the request has been made by the client.
  /// The name has been replaced because it contains a keyword. Original name: `When`.
  @JsonKey(name: 'When')
  final DateTime? whenValue;

  /// Gets or sets the position ticks.
  @JsonKey(name: 'PositionTicks')
  final int? positionTicks;

  /// Gets or sets a value indicating whether the client playback is unpaused.
  @JsonKey(name: 'IsPlaying')
  final bool? isPlaying;

  /// Gets or sets the playlist item identifier of the playing item.
  @JsonKey(name: 'PlaylistItemId')
  final String? playlistItemId;

  Map<String, Object?> toJson() => _$BufferRequestDtoToJson(this);
}
