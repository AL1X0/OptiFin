// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum TranscodeReason {
  @JsonValue('ContainerNotSupported')
  containerNotSupported('ContainerNotSupported'),
  @JsonValue('VideoCodecNotSupported')
  videoCodecNotSupported('VideoCodecNotSupported'),
  @JsonValue('AudioCodecNotSupported')
  audioCodecNotSupported('AudioCodecNotSupported'),
  @JsonValue('SubtitleCodecNotSupported')
  subtitleCodecNotSupported('SubtitleCodecNotSupported'),
  @JsonValue('AudioIsExternal')
  audioIsExternal('AudioIsExternal'),
  @JsonValue('SecondaryAudioNotSupported')
  secondaryAudioNotSupported('SecondaryAudioNotSupported'),
  @JsonValue('VideoProfileNotSupported')
  videoProfileNotSupported('VideoProfileNotSupported'),
  @JsonValue('VideoLevelNotSupported')
  videoLevelNotSupported('VideoLevelNotSupported'),
  @JsonValue('VideoResolutionNotSupported')
  videoResolutionNotSupported('VideoResolutionNotSupported'),
  @JsonValue('VideoBitDepthNotSupported')
  videoBitDepthNotSupported('VideoBitDepthNotSupported'),
  @JsonValue('VideoFramerateNotSupported')
  videoFramerateNotSupported('VideoFramerateNotSupported'),
  @JsonValue('RefFramesNotSupported')
  refFramesNotSupported('RefFramesNotSupported'),
  @JsonValue('AnamorphicVideoNotSupported')
  anamorphicVideoNotSupported('AnamorphicVideoNotSupported'),
  @JsonValue('InterlacedVideoNotSupported')
  interlacedVideoNotSupported('InterlacedVideoNotSupported'),
  @JsonValue('AudioChannelsNotSupported')
  audioChannelsNotSupported('AudioChannelsNotSupported'),
  @JsonValue('AudioProfileNotSupported')
  audioProfileNotSupported('AudioProfileNotSupported'),
  @JsonValue('AudioSampleRateNotSupported')
  audioSampleRateNotSupported('AudioSampleRateNotSupported'),
  @JsonValue('AudioBitDepthNotSupported')
  audioBitDepthNotSupported('AudioBitDepthNotSupported'),
  @JsonValue('ContainerBitrateExceedsLimit')
  containerBitrateExceedsLimit('ContainerBitrateExceedsLimit'),
  @JsonValue('VideoBitrateNotSupported')
  videoBitrateNotSupported('VideoBitrateNotSupported'),
  @JsonValue('AudioBitrateNotSupported')
  audioBitrateNotSupported('AudioBitrateNotSupported'),
  @JsonValue('UnknownVideoStreamInfo')
  unknownVideoStreamInfo('UnknownVideoStreamInfo'),
  @JsonValue('UnknownAudioStreamInfo')
  unknownAudioStreamInfo('UnknownAudioStreamInfo'),
  @JsonValue('DirectPlayError')
  directPlayError('DirectPlayError'),
  @JsonValue('VideoRangeTypeNotSupported')
  videoRangeTypeNotSupported('VideoRangeTypeNotSupported'),
  @JsonValue('VideoCodecTagNotSupported')
  videoCodecTagNotSupported('VideoCodecTagNotSupported'),
  @JsonValue('StreamCountExceedsLimit')
  streamCountExceedsLimit('StreamCountExceedsLimit'),
  @JsonValue('VideoRotationNotSupported')
  videoRotationNotSupported('VideoRotationNotSupported'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const TranscodeReason(this.json);

  factory TranscodeReason.fromJson(String json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final String? json;
  String toJson() {
    final value = json;
    if (value == null) {
      throw StateError('Cannot convert enum value with null JSON representation to String. '
          'This usually happens for \$unknown or @JsonValue(null) entries.');
    }
    return value as String;
  }

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<TranscodeReason> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
