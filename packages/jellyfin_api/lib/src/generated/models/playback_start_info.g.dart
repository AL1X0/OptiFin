// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_start_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlaybackStartInfo _$PlaybackStartInfoFromJson(Map<String, dynamic> json) =>
    PlaybackStartInfo(
      canSeek: json['CanSeek'] as bool?,
      item: json['Item'] == null
          ? null
          : BaseItemDto.fromJson(json['Item'] as Map<String, dynamic>),
      itemId: json['ItemId'] as String?,
      sessionId: json['SessionId'] as String?,
      mediaSourceId: json['MediaSourceId'] as String?,
      audioStreamIndex: (json['AudioStreamIndex'] as num?)?.toInt(),
      subtitleStreamIndex: (json['SubtitleStreamIndex'] as num?)?.toInt(),
      isPaused: json['IsPaused'] as bool?,
      isMuted: json['IsMuted'] as bool?,
      positionTicks: (json['PositionTicks'] as num?)?.toInt(),
      playbackStartTimeTicks: (json['PlaybackStartTimeTicks'] as num?)?.toInt(),
      volumeLevel: (json['VolumeLevel'] as num?)?.toInt(),
      brightness: (json['Brightness'] as num?)?.toInt(),
      aspectRatio: json['AspectRatio'] as String?,
      playMethod: json['PlayMethod'] == null
          ? null
          : PlaybackStartInfoPlayMethod.fromJson(json['PlayMethod']),
      liveStreamId: json['LiveStreamId'] as String?,
      playSessionId: json['PlaySessionId'] as String?,
      repeatMode: json['RepeatMode'] == null
          ? null
          : PlaybackStartInfoRepeatMode.fromJson(json['RepeatMode']),
      playbackOrder: json['PlaybackOrder'] == null
          ? null
          : PlaybackStartInfoPlaybackOrder.fromJson(json['PlaybackOrder']),
      nowPlayingQueue: (json['NowPlayingQueue'] as List<dynamic>?)
          ?.map((e) => QueueItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      playlistItemId: json['PlaylistItemId'] as String?,
    );

Map<String, dynamic> _$PlaybackStartInfoToJson(PlaybackStartInfo instance) =>
    <String, dynamic>{
      'CanSeek': ?instance.canSeek,
      'Item': ?instance.item,
      'ItemId': ?instance.itemId,
      'SessionId': ?instance.sessionId,
      'MediaSourceId': ?instance.mediaSourceId,
      'AudioStreamIndex': ?instance.audioStreamIndex,
      'SubtitleStreamIndex': ?instance.subtitleStreamIndex,
      'IsPaused': ?instance.isPaused,
      'IsMuted': ?instance.isMuted,
      'PositionTicks': ?instance.positionTicks,
      'PlaybackStartTimeTicks': ?instance.playbackStartTimeTicks,
      'VolumeLevel': ?instance.volumeLevel,
      'Brightness': ?instance.brightness,
      'AspectRatio': ?instance.aspectRatio,
      'PlayMethod': ?instance.playMethod,
      'LiveStreamId': ?instance.liveStreamId,
      'PlaySessionId': ?instance.playSessionId,
      'RepeatMode': ?instance.repeatMode,
      'PlaybackOrder': ?instance.playbackOrder,
      'NowPlayingQueue': ?instance.nowPlayingQueue,
      'PlaylistItemId': ?instance.playlistItemId,
    };
