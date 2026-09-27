// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'media_source_info.dart';

part 'live_stream_response.g.dart';

@JsonSerializable()
class LiveStreamResponse {
  const LiveStreamResponse({
    required this.mediaSource,
  });
  
  factory LiveStreamResponse.fromJson(Map<String, Object?> json) => _$LiveStreamResponseFromJson(json);
  
  @JsonKey(name: 'MediaSource')
  final MediaSourceInfo? mediaSource;

  Map<String, Object?> toJson() => _$LiveStreamResponseToJson(this);
}
