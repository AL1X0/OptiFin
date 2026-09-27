// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum ProfileConditionValue {
  @JsonValue('AudioChannels')
  audioChannels('AudioChannels'),
  @JsonValue('AudioBitrate')
  audioBitrate('AudioBitrate'),
  @JsonValue('AudioProfile')
  audioProfile('AudioProfile'),
  @JsonValue('Width')
  width('Width'),
  @JsonValue('Height')
  height('Height'),
  @JsonValue('Has64BitOffsets')
  has64BitOffsets('Has64BitOffsets'),
  @JsonValue('PacketLength')
  packetLength('PacketLength'),
  @JsonValue('VideoBitDepth')
  videoBitDepth('VideoBitDepth'),
  @JsonValue('VideoBitrate')
  videoBitrate('VideoBitrate'),
  @JsonValue('VideoFramerate')
  videoFramerate('VideoFramerate'),
  @JsonValue('VideoLevel')
  videoLevel('VideoLevel'),
  @JsonValue('VideoProfile')
  videoProfile('VideoProfile'),
  @JsonValue('VideoTimestamp')
  videoTimestamp('VideoTimestamp'),
  @JsonValue('IsAnamorphic')
  isAnamorphic('IsAnamorphic'),
  @JsonValue('RefFrames')
  refFrames('RefFrames'),
  @JsonValue('NumAudioStreams')
  numAudioStreams('NumAudioStreams'),
  @JsonValue('NumVideoStreams')
  numVideoStreams('NumVideoStreams'),
  @JsonValue('IsSecondaryAudio')
  isSecondaryAudio('IsSecondaryAudio'),
  @JsonValue('VideoCodecTag')
  videoCodecTag('VideoCodecTag'),
  @JsonValue('IsAvc')
  isAvc('IsAvc'),
  @JsonValue('IsInterlaced')
  isInterlaced('IsInterlaced'),
  @JsonValue('AudioSampleRate')
  audioSampleRate('AudioSampleRate'),
  @JsonValue('AudioBitDepth')
  audioBitDepth('AudioBitDepth'),
  @JsonValue('VideoRangeType')
  videoRangeType('VideoRangeType'),
  @JsonValue('NumStreams')
  numStreams('NumStreams'),
  @JsonValue('VideoRotation')
  videoRotation('VideoRotation'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const ProfileConditionValue(this.json);

  factory ProfileConditionValue.fromJson(String json) => values.firstWhere(
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
  static List<ProfileConditionValue> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
