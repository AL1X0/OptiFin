// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'profile_condition.dart';
import 'transcoding_profile_context.dart';
import 'transcoding_profile_protocol.dart';
import 'transcoding_profile_transcode_seek_info.dart';
import 'transcoding_profile_type.dart';

part 'transcoding_profile.g.dart';

/// A class for transcoding profile information.
/// Note for client developers: Conditions defined in MediaBrowser.Model.Dlna.CodecProfile has higher priority and can override values defined here.
@JsonSerializable()
class TranscodingProfile {
  const TranscodingProfile({
    required this.container,
    required this.type,
    required this.videoCodec,
    required this.audioCodec,
    required this.protocol,
    required this.transcodeSeekInfo,
    required this.context,
    required this.maxAudioChannels,
    required this.conditions,
    this.estimateContentLength = false,
    this.enableMpegtsM2TsMode = false,
    this.copyTimestamps = false,
    this.enableSubtitlesInManifest = false,
    this.minSegments = 0,
    this.segmentLength = 0,
    this.breakOnNonKeyFrames = false,
    this.enableAudioVbrEncoding = true,
  });
  
  factory TranscodingProfile.fromJson(Map<String, Object?> json) => _$TranscodingProfileFromJson(json);
  
  /// Gets or sets the container.
  @JsonKey(name: 'Container')
  final String container;

  /// Gets or sets the DLNA profile type.
  @JsonKey(name: 'Type')
  final TranscodingProfileType type;

  /// Gets or sets the video codec.
  @JsonKey(name: 'VideoCodec')
  final String videoCodec;

  /// Gets or sets the audio codec.
  @JsonKey(name: 'AudioCodec')
  final String audioCodec;

  /// Media streaming protocol.
  /// Lowercase for backwards compatibility.
  @JsonKey(name: 'Protocol')
  final TranscodingProfileProtocol protocol;

  /// Gets or sets a value indicating whether the content length should be estimated.
  @JsonKey(name: 'EstimateContentLength')
  final bool estimateContentLength;

  /// Gets or sets a value indicating whether M2TS mode is enabled.
  @JsonKey(name: 'EnableMpegtsM2TsMode')
  final bool enableMpegtsM2TsMode;

  /// Gets or sets the transcoding seek info mode.
  @JsonKey(name: 'TranscodeSeekInfo')
  final TranscodingProfileTranscodeSeekInfo transcodeSeekInfo;

  /// Gets or sets a value indicating whether timestamps should be copied.
  @JsonKey(name: 'CopyTimestamps')
  final bool copyTimestamps;

  /// Gets or sets the encoding context.
  @JsonKey(name: 'Context')
  final TranscodingProfileContext context;

  /// Gets or sets a value indicating whether subtitles are allowed in the manifest.
  @JsonKey(name: 'EnableSubtitlesInManifest')
  final bool enableSubtitlesInManifest;

  /// Gets or sets the maximum audio channels.
  @JsonKey(name: 'MaxAudioChannels')
  final String? maxAudioChannels;

  /// Gets or sets the minimum amount of segments.
  @JsonKey(name: 'MinSegments')
  final int minSegments;

  /// Gets or sets the segment length.
  @JsonKey(name: 'SegmentLength')
  final int segmentLength;

  /// Gets or sets a value indicating whether breaking the video stream on non-keyframes is supported.
  @JsonKey(name: 'BreakOnNonKeyFrames')
  final bool? breakOnNonKeyFrames;

  /// Gets or sets the profile conditions.
  @JsonKey(name: 'Conditions')
  final List<ProfileCondition> conditions;

  /// Gets or sets a value indicating whether variable bitrate encoding is supported.
  @JsonKey(name: 'EnableAudioVbrEncoding')
  final bool enableAudioVbrEncoding;

  Map<String, Object?> toJson() => _$TranscodingProfileToJson(this);
}
