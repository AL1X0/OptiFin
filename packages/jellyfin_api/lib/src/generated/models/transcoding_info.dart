// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'transcode_reason.dart';
import 'transcoding_info_hardware_acceleration_type.dart';

part 'transcoding_info.g.dart';

/// Class holding information on a running transcode.
@JsonSerializable()
class TranscodingInfo {
  const TranscodingInfo({
    required this.audioCodec,
    required this.videoCodec,
    required this.container,
    required this.isVideoDirect,
    required this.isAudioDirect,
    required this.bitrate,
    required this.framerate,
    required this.completionPercentage,
    required this.width,
    required this.height,
    required this.audioChannels,
    required this.hardwareAccelerationType,
    required this.transcodeReasons,
  });
  
  factory TranscodingInfo.fromJson(Map<String, Object?> json) => _$TranscodingInfoFromJson(json);
  
  /// Gets or sets the thread count used for encoding.
  @JsonKey(name: 'AudioCodec')
  final String? audioCodec;

  /// Gets or sets the thread count used for encoding.
  @JsonKey(name: 'VideoCodec')
  final String? videoCodec;

  /// Gets or sets the thread count used for encoding.
  @JsonKey(name: 'Container')
  final String? container;

  /// Gets or sets a value indicating whether the video is passed through.
  @JsonKey(name: 'IsVideoDirect')
  final bool? isVideoDirect;

  /// Gets or sets a value indicating whether the audio is passed through.
  @JsonKey(name: 'IsAudioDirect')
  final bool? isAudioDirect;

  /// Gets or sets the bitrate.
  @JsonKey(name: 'Bitrate')
  final int? bitrate;

  /// Gets or sets the framerate.
  @JsonKey(name: 'Framerate')
  final double? framerate;

  /// Gets or sets the completion percentage.
  @JsonKey(name: 'CompletionPercentage')
  final double? completionPercentage;

  /// Gets or sets the video width.
  @JsonKey(name: 'Width')
  final int? width;

  /// Gets or sets the video height.
  @JsonKey(name: 'Height')
  final int? height;

  /// Gets or sets the audio channels.
  @JsonKey(name: 'AudioChannels')
  final int? audioChannels;

  /// Gets or sets the hardware acceleration type.
  @JsonKey(name: 'HardwareAccelerationType')
  final TranscodingInfoHardwareAccelerationType? hardwareAccelerationType;

  /// Gets or sets the transcode reasons.
  @JsonKey(name: 'TranscodeReasons')
  final List<TranscodeReason>? transcodeReasons;

  Map<String, Object?> toJson() => _$TranscodingInfoToJson(this);
}
