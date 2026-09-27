// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcoding_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TranscodingInfo _$TranscodingInfoFromJson(Map<String, dynamic> json) =>
    TranscodingInfo(
      audioCodec: json['AudioCodec'] as String?,
      videoCodec: json['VideoCodec'] as String?,
      container: json['Container'] as String?,
      isVideoDirect: json['IsVideoDirect'] as bool?,
      isAudioDirect: json['IsAudioDirect'] as bool?,
      bitrate: (json['Bitrate'] as num?)?.toInt(),
      framerate: (json['Framerate'] as num?)?.toDouble(),
      completionPercentage: (json['CompletionPercentage'] as num?)?.toDouble(),
      width: (json['Width'] as num?)?.toInt(),
      height: (json['Height'] as num?)?.toInt(),
      audioChannels: (json['AudioChannels'] as num?)?.toInt(),
      hardwareAccelerationType: json['HardwareAccelerationType'] == null
          ? null
          : TranscodingInfoHardwareAccelerationType.fromJson(
              json['HardwareAccelerationType'],
            ),
      transcodeReasons: (json['TranscodeReasons'] as List<dynamic>?)
          ?.map((e) => TranscodeReason.fromJson(e as String))
          .toList(),
    );

Map<String, dynamic> _$TranscodingInfoToJson(TranscodingInfo instance) =>
    <String, dynamic>{
      'AudioCodec': instance.audioCodec,
      'VideoCodec': instance.videoCodec,
      'Container': instance.container,
      'IsVideoDirect': instance.isVideoDirect,
      'IsAudioDirect': instance.isAudioDirect,
      'Bitrate': instance.bitrate,
      'Framerate': instance.framerate,
      'CompletionPercentage': instance.completionPercentage,
      'Width': instance.width,
      'Height': instance.height,
      'AudioChannels': instance.audioChannels,
      'HardwareAccelerationType': instance.hardwareAccelerationType,
      'TranscodeReasons': instance.transcodeReasons,
    };
