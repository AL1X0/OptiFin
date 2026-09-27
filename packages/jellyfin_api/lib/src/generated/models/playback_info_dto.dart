// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'device_profile.dart';

part 'playback_info_dto.g.dart';

/// Playback info dto.
@JsonSerializable()
class PlaybackInfoDto {
  const PlaybackInfoDto({
    required this.userId,
    required this.maxStreamingBitrate,
    required this.startTimeTicks,
    required this.audioStreamIndex,
    required this.subtitleStreamIndex,
    required this.maxAudioChannels,
    required this.mediaSourceId,
    required this.liveStreamId,
    required this.deviceProfile,
    required this.enableDirectPlay,
    required this.enableDirectStream,
    required this.enableTranscoding,
    required this.allowVideoStreamCopy,
    required this.allowAudioStreamCopy,
    required this.autoOpenLiveStream,
    required this.alwaysBurnInSubtitleWhenTranscoding,
  });
  
  factory PlaybackInfoDto.fromJson(Map<String, Object?> json) => _$PlaybackInfoDtoFromJson(json);
  
  /// Gets or sets the playback userId.
  @JsonKey(name: 'UserId')
  final String? userId;

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

  /// Gets or sets the media source id.
  @JsonKey(name: 'MediaSourceId')
  final String? mediaSourceId;

  /// Gets or sets the live stream id.
  @JsonKey(name: 'LiveStreamId')
  final String? liveStreamId;

  /// Gets or sets the device profile.
  @JsonKey(name: 'DeviceProfile')
  final DeviceProfile? deviceProfile;

  /// Gets or sets a value indicating whether to enable direct play.
  @JsonKey(name: 'EnableDirectPlay')
  final bool? enableDirectPlay;

  /// Gets or sets a value indicating whether to enable direct stream.
  @JsonKey(name: 'EnableDirectStream')
  final bool? enableDirectStream;

  /// Gets or sets a value indicating whether to enable transcoding.
  @JsonKey(name: 'EnableTranscoding')
  final bool? enableTranscoding;

  /// Gets or sets a value indicating whether to enable video stream copy.
  @JsonKey(name: 'AllowVideoStreamCopy')
  final bool? allowVideoStreamCopy;

  /// Gets or sets a value indicating whether to allow audio stream copy.
  @JsonKey(name: 'AllowAudioStreamCopy')
  final bool? allowAudioStreamCopy;

  /// Gets or sets a value indicating whether to auto open the live stream.
  @JsonKey(name: 'AutoOpenLiveStream')
  final bool? autoOpenLiveStream;

  /// Gets or sets a value indicating whether always burn in subtitles when transcoding.
  @JsonKey(name: 'AlwaysBurnInSubtitleWhenTranscoding')
  final bool? alwaysBurnInSubtitleWhenTranscoding;

  Map<String, Object?> toJson() => _$PlaybackInfoDtoToJson(this);
}
