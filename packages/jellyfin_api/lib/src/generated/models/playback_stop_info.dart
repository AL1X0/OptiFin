// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'base_item_dto.dart';
import 'queue_item.dart';

part 'playback_stop_info.g.dart';

/// Class PlaybackStopInfo.
@JsonSerializable()
class PlaybackStopInfo {
  const PlaybackStopInfo({
    required this.item,
    required this.itemId,
    required this.sessionId,
    required this.mediaSourceId,
    required this.positionTicks,
    required this.liveStreamId,
    required this.playSessionId,
    required this.failed,
    required this.nextMediaType,
    required this.playlistItemId,
    required this.nowPlayingQueue,
  });
  
  factory PlaybackStopInfo.fromJson(Map<String, Object?> json) => _$PlaybackStopInfoFromJson(json);
  
  /// Gets or sets the item.
  @JsonKey(name: 'Item')
  final BaseItemDto? item;

  /// Gets or sets the item identifier.
  @JsonKey(name: 'ItemId')
  final String? itemId;

  /// Gets or sets the session id.
  @JsonKey(name: 'SessionId')
  final String? sessionId;

  /// Gets or sets the media version identifier.
  @JsonKey(name: 'MediaSourceId')
  final String? mediaSourceId;

  /// Gets or sets the position ticks.
  @JsonKey(name: 'PositionTicks')
  final int? positionTicks;

  /// Gets or sets the live stream identifier.
  @JsonKey(name: 'LiveStreamId')
  final String? liveStreamId;

  /// Gets or sets the play session identifier.
  @JsonKey(name: 'PlaySessionId')
  final String? playSessionId;

  /// Gets or sets a value indicating whether this MediaBrowser.Model.Session.PlaybackStopInfo is failed.
  @JsonKey(name: 'Failed')
  final bool? failed;
  @JsonKey(name: 'NextMediaType')
  final String? nextMediaType;
  @JsonKey(name: 'PlaylistItemId')
  final String? playlistItemId;
  @JsonKey(name: 'NowPlayingQueue')
  final List<QueueItem>? nowPlayingQueue;

  Map<String, Object?> toJson() => _$PlaybackStopInfoToJson(this);
}
