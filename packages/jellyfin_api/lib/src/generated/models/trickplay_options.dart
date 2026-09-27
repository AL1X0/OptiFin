// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'trickplay_options_process_priority.dart';
import 'trickplay_options_scan_behavior.dart';

part 'trickplay_options.g.dart';

/// Class TrickplayOptions.
@JsonSerializable()
class TrickplayOptions {
  const TrickplayOptions({
    required this.enableHwAcceleration,
    required this.enableHwEncoding,
    required this.enableKeyFrameOnlyExtraction,
    required this.scanBehavior,
    required this.processPriority,
    required this.interval,
    required this.widthResolutions,
    required this.tileWidth,
    required this.tileHeight,
    required this.qscale,
    required this.jpegQuality,
    required this.processThreads,
  });
  
  factory TrickplayOptions.fromJson(Map<String, Object?> json) => _$TrickplayOptionsFromJson(json);
  
  /// Gets or sets a value indicating whether or not to use HW acceleration.
  @JsonKey(name: 'EnableHwAcceleration')
  final bool enableHwAcceleration;

  /// Gets or sets a value indicating whether or not to use HW accelerated MJPEG encoding.
  @JsonKey(name: 'EnableHwEncoding')
  final bool enableHwEncoding;

  /// Gets or sets a value indicating whether to only extract key frames.
  /// Significantly faster, but is not compatible with all decoders and/or video files.
  @JsonKey(name: 'EnableKeyFrameOnlyExtraction')
  final bool enableKeyFrameOnlyExtraction;

  /// Gets or sets the behavior used by trickplay provider on library scan/update.
  @JsonKey(name: 'ScanBehavior')
  final TrickplayOptionsScanBehavior scanBehavior;

  /// Gets or sets the process priority for the ffmpeg process.
  @JsonKey(name: 'ProcessPriority')
  final TrickplayOptionsProcessPriority processPriority;

  /// Gets or sets the interval, in ms, between each new trickplay image.
  @JsonKey(name: 'Interval')
  final int interval;

  /// Gets or sets the target width resolutions, in px, to generates preview images for.
  @JsonKey(name: 'WidthResolutions')
  final List<int> widthResolutions;

  /// Gets or sets number of tile images to allow in X dimension.
  @JsonKey(name: 'TileWidth')
  final int tileWidth;

  /// Gets or sets number of tile images to allow in Y dimension.
  @JsonKey(name: 'TileHeight')
  final int tileHeight;

  /// Gets or sets the ffmpeg output quality level.
  @JsonKey(name: 'Qscale')
  final int qscale;

  /// Gets or sets the jpeg quality to use for image tiles.
  @JsonKey(name: 'JpegQuality')
  final int jpegQuality;

  /// Gets or sets the number of threads to be used by ffmpeg.
  @JsonKey(name: 'ProcessThreads')
  final int processThreads;

  Map<String, Object?> toJson() => _$TrickplayOptionsToJson(this);
}
