// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_stop_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlaybackStopInfo _$PlaybackStopInfoFromJson(Map<String, dynamic> json) =>
    PlaybackStopInfo(
      item: json['Item'] == null
          ? null
          : BaseItemDto.fromJson(json['Item'] as Map<String, dynamic>),
      itemId: json['ItemId'] as String?,
      sessionId: json['SessionId'] as String?,
      mediaSourceId: json['MediaSourceId'] as String?,
      positionTicks: (json['PositionTicks'] as num?)?.toInt(),
      liveStreamId: json['LiveStreamId'] as String?,
      playSessionId: json['PlaySessionId'] as String?,
      failed: json['Failed'] as bool?,
      nextMediaType: json['NextMediaType'] as String?,
      playlistItemId: json['PlaylistItemId'] as String?,
      nowPlayingQueue: (json['NowPlayingQueue'] as List<dynamic>?)
          ?.map((e) => QueueItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PlaybackStopInfoToJson(PlaybackStopInfo instance) =>
    <String, dynamic>{
      'Item': instance.item,
      'ItemId': instance.itemId,
      'SessionId': instance.sessionId,
      'MediaSourceId': instance.mediaSourceId,
      'PositionTicks': instance.positionTicks,
      'LiveStreamId': instance.liveStreamId,
      'PlaySessionId': instance.playSessionId,
      'Failed': instance.failed,
      'NextMediaType': instance.nextMediaType,
      'PlaylistItemId': instance.playlistItemId,
      'NowPlayingQueue': instance.nowPlayingQueue,
    };
