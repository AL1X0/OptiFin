// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'device_profile.dart';
import 'media_protocol.dart';

part 'open_live_stream_dto.g.dart';

/// Open live stream dto.
@JsonSerializable()
class OpenLiveStreamDto {
  const OpenLiveStreamDto({
    required this.openToken,
    required this.userId,
    required this.playSessionId,
    required this.maxStreamingBitrate,
    required this.startTimeTicks,
    required this.audioStreamIndex,
    required this.subtitleStreamIndex,
    required this.maxAudioChannels,
    required this.itemId,
    required this.enableDirectPlay,
    required this.enableDirectStream,
    required this.alwaysBurnInSubtitleWhenTranscoding,
    required this.deviceProfile,
    required this.directPlayProtocols,
  });
  
  factory OpenLiveStreamDto.fromJson(Map<String, Object?> json) => _$OpenLiveStreamDtoFromJson(json);
  
  /// Gets or sets the open token.
  @JsonKey(name: 'OpenToken')
  final String? openToken;

  /// Gets or sets the user id.
  @JsonKey(name: 'UserId')
  final String? userId;

  /// Gets or sets the play session id.
  @JsonKey(name: 'PlaySessionId')
  final String? playSessionId;

  /// Gets or sets the max streaming bitrate.
  @JsonKey(name: 'MaxStreamingBitrate')
  final int? maxStreamingBitrate;

  /// Gets or sets the start time in ticks.
  @JsonKey(name: 'StartTimeTicks')
  final int? startTimeTicks;

  /// Gets or sets the audio stream index.
  @JsonKey(name: 'AudioStreamIndex')
  final int? audioStreamIndex;

  /// Gets or sets the subtitle stream index.
  @JsonKey(name: 'SubtitleStreamIndex')
  final int? subtitleStreamIndex;

  /// Gets or sets the max audio channels.
  @JsonKey(name: 'MaxAudioChannels')
  final int? maxAudioChannels;

  /// Gets or sets the item id.
  @JsonKey(name: 'ItemId')
  final String? itemId;

  /// Gets or sets a value indicating whether to enable direct play.
  @JsonKey(name: 'EnableDirectPlay')
  final bool? enableDirectPlay;

  /// Gets or sets a value indicating whether to enable direct stream.
  @JsonKey(name: 'EnableDirectStream')
  final bool? enableDirectStream;

  /// Gets or sets a value indicating whether always burn in subtitles when transcoding.
  @JsonKey(name: 'AlwaysBurnInSubtitleWhenTranscoding')
  final bool? alwaysBurnInSubtitleWhenTranscoding;

  /// Gets or sets the device profile.
  @JsonKey(name: 'DeviceProfile')
  final DeviceProfile? deviceProfile;

  /// Gets or sets the device play protocols.
  @JsonKey(name: 'DirectPlayProtocols')
  final List<MediaProtocol>? directPlayProtocols;

  Map<String, Object?> toJson() => _$OpenLiveStreamDtoToJson(this);
}
