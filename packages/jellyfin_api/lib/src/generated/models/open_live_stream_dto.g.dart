// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_live_stream_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OpenLiveStreamDto _$OpenLiveStreamDtoFromJson(Map<String, dynamic> json) =>
    OpenLiveStreamDto(
      openToken: json['OpenToken'] as String?,
      userId: json['UserId'] as String?,
      playSessionId: json['PlaySessionId'] as String?,
      maxStreamingBitrate: (json['MaxStreamingBitrate'] as num?)?.toInt(),
      startTimeTicks: (json['StartTimeTicks'] as num?)?.toInt(),
      audioStreamIndex: (json['AudioStreamIndex'] as num?)?.toInt(),
      subtitleStreamIndex: (json['SubtitleStreamIndex'] as num?)?.toInt(),
      maxAudioChannels: (json['MaxAudioChannels'] as num?)?.toInt(),
      itemId: json['ItemId'] as String?,
      enableDirectPlay: json['EnableDirectPlay'] as bool?,
      enableDirectStream: json['EnableDirectStream'] as bool?,
      alwaysBurnInSubtitleWhenTranscoding:
          json['AlwaysBurnInSubtitleWhenTranscoding'] as bool?,
      deviceProfile: json['DeviceProfile'] == null
          ? null
          : DeviceProfile.fromJson(
              json['DeviceProfile'] as Map<String, dynamic>,
            ),
      directPlayProtocols: (json['DirectPlayProtocols'] as List<dynamic>?)
          ?.map((e) => MediaProtocol.fromJson(e as String))
          .toList(),
    );

Map<String, dynamic> _$OpenLiveStreamDtoToJson(OpenLiveStreamDto instance) =>
    <String, dynamic>{
      'OpenToken': instance.openToken,
      'UserId': instance.userId,
      'PlaySessionId': instance.playSessionId,
      'MaxStreamingBitrate': instance.maxStreamingBitrate,
      'StartTimeTicks': instance.startTimeTicks,
      'AudioStreamIndex': instance.audioStreamIndex,
      'SubtitleStreamIndex': instance.subtitleStreamIndex,
      'MaxAudioChannels': instance.maxAudioChannels,
      'ItemId': instance.itemId,
      'EnableDirectPlay': instance.enableDirectPlay,
      'EnableDirectStream': instance.enableDirectStream,
      'AlwaysBurnInSubtitleWhenTranscoding':
          instance.alwaysBurnInSubtitleWhenTranscoding,
      'DeviceProfile': instance.deviceProfile,
      'DirectPlayProtocols': instance.directPlayProtocols,
    };
