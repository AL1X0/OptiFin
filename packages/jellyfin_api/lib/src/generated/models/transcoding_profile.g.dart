// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcoding_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TranscodingProfile _$TranscodingProfileFromJson(Map<String, dynamic> json) =>
    TranscodingProfile(
      container: json['Container'] as String?,
      type: json['Type'] == null
          ? null
          : TranscodingProfileType.fromJson(json['Type']),
      videoCodec: json['VideoCodec'] as String?,
      audioCodec: json['AudioCodec'] as String?,
      protocol: json['Protocol'] == null
          ? null
          : TranscodingProfileProtocol.fromJson(json['Protocol']),
      transcodeSeekInfo: json['TranscodeSeekInfo'] == null
          ? null
          : TranscodingProfileTranscodeSeekInfo.fromJson(
              json['TranscodeSeekInfo'],
            ),
      context: json['Context'] == null
          ? null
          : TranscodingProfileContext.fromJson(json['Context']),
      maxAudioChannels: json['MaxAudioChannels'] as String?,
      conditions: (json['Conditions'] as List<dynamic>?)
          ?.map((e) => ProfileCondition.fromJson(e as Map<String, dynamic>))
          .toList(),
      estimateContentLength: json['EstimateContentLength'] as bool? ?? false,
      enableMpegtsM2TsMode: json['EnableMpegtsM2TsMode'] as bool? ?? false,
      copyTimestamps: json['CopyTimestamps'] as bool? ?? false,
      enableSubtitlesInManifest:
          json['EnableSubtitlesInManifest'] as bool? ?? false,
      minSegments: (json['MinSegments'] as num?)?.toInt() ?? 0,
      segmentLength: (json['SegmentLength'] as num?)?.toInt() ?? 0,
      breakOnNonKeyFrames: json['BreakOnNonKeyFrames'] as bool? ?? false,
      enableAudioVbrEncoding: json['EnableAudioVbrEncoding'] as bool? ?? true,
    );

Map<String, dynamic> _$TranscodingProfileToJson(TranscodingProfile instance) =>
    <String, dynamic>{
      'Container': instance.container,
      'Type': instance.type,
      'VideoCodec': instance.videoCodec,
      'AudioCodec': instance.audioCodec,
      'Protocol': instance.protocol,
      'EstimateContentLength': instance.estimateContentLength,
      'EnableMpegtsM2TsMode': instance.enableMpegtsM2TsMode,
      'TranscodeSeekInfo': instance.transcodeSeekInfo,
      'CopyTimestamps': instance.copyTimestamps,
      'Context': instance.context,
      'EnableSubtitlesInManifest': instance.enableSubtitlesInManifest,
      'MaxAudioChannels': instance.maxAudioChannels,
      'MinSegments': instance.minSegments,
      'SegmentLength': instance.segmentLength,
      'BreakOnNonKeyFrames': instance.breakOnNonKeyFrames,
      'Conditions': instance.conditions,
      'EnableAudioVbrEncoding': instance.enableAudioVbrEncoding,
    };
