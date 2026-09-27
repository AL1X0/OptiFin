// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_state_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlayerStateInfo _$PlayerStateInfoFromJson(Map<String, dynamic> json) =>
    PlayerStateInfo(
      positionTicks: (json['PositionTicks'] as num?)?.toInt(),
      canSeek: json['CanSeek'] as bool?,
      isPaused: json['IsPaused'] as bool?,
      isMuted: json['IsMuted'] as bool?,
      volumeLevel: (json['VolumeLevel'] as num?)?.toInt(),
      audioStreamIndex: (json['AudioStreamIndex'] as num?)?.toInt(),
      subtitleStreamIndex: (json['SubtitleStreamIndex'] as num?)?.toInt(),
      mediaSourceId: json['MediaSourceId'] as String?,
      playMethod: json['PlayMethod'] == null
          ? null
          : PlayerStateInfoPlayMethod.fromJson(json['PlayMethod']),
      repeatMode: json['RepeatMode'] == null
          ? null
          : PlayerStateInfoRepeatMode.fromJson(json['RepeatMode']),
      playbackOrder: json['PlaybackOrder'] == null
          ? null
          : PlayerStateInfoPlaybackOrder.fromJson(json['PlaybackOrder']),
      liveStreamId: json['LiveStreamId'] as String?,
    );

Map<String, dynamic> _$PlayerStateInfoToJson(PlayerStateInfo instance) =>
    <String, dynamic>{
      'PositionTicks': instance.positionTicks,
      'CanSeek': instance.canSeek,
      'IsPaused': instance.isPaused,
      'IsMuted': instance.isMuted,
      'VolumeLevel': instance.volumeLevel,
      'AudioStreamIndex': instance.audioStreamIndex,
      'SubtitleStreamIndex': instance.subtitleStreamIndex,
      'MediaSourceId': instance.mediaSourceId,
      'PlayMethod': instance.playMethod,
      'RepeatMode': instance.repeatMode,
      'PlaybackOrder': instance.playbackOrder,
      'LiveStreamId': instance.liveStreamId,
    };
