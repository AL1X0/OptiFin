// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'media_source_info.dart';
import 'playback_info_response_error_code.dart';

part 'playback_info_response.g.dart';

/// Class PlaybackInfoResponse.
@JsonSerializable()
class PlaybackInfoResponse {
  const PlaybackInfoResponse({
    required this.mediaSources,
    required this.playSessionId,
    required this.errorCode,
  });
  
  factory PlaybackInfoResponse.fromJson(Map<String, Object?> json) => _$PlaybackInfoResponseFromJson(json);
  
  /// Gets or sets the media sources.
  @JsonKey(name: 'MediaSources')
  final List<MediaSourceInfo> mediaSources;

  /// Gets or sets the play session identifier.
  @JsonKey(name: 'PlaySessionId')
  final String? playSessionId;

  /// Gets or sets the error code.
  @JsonKey(name: 'ErrorCode')
  final PlaybackInfoResponseErrorCode? errorCode;

  Map<String, Object?> toJson() => _$PlaybackInfoResponseToJson(this);
}
