// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'base_item_dto.dart';
import 'playback_start_info_play_method.dart';
import 'playback_start_info_playback_order.dart';
import 'playback_start_info_repeat_mode.dart';
import 'queue_item.dart';

part 'playback_start_info.g.dart';

/// Class PlaybackStartInfo.
@JsonSerializable()
class PlaybackStartInfo {
  const PlaybackStartInfo({
    required this.canSeek,
    required this.item,
    required this.itemId,
    required this.sessionId,
    required this.mediaSourceId,
    required this.audioStreamIndex,
    required this.subtitleStreamIndex,
    required this.isPaused,
    required this.isMuted,
    required this.positionTicks,
    required this.playbackStartTimeTicks,
    required this.volumeLevel,
    required this.brightness,
    required this.aspectRatio,
    required this.playMethod,
    required this.liveStreamId,
    required this.playSessionId,
    required this.repeatMode,
    required this.playbackOrder,
    required this.nowPlayingQueue,
    required this.playlistItemId,
  });
  
  factory PlaybackStartInfo.fromJson(Map<String, Object?> json) => _$PlaybackStartInfoFromJson(json);
  
  /// Gets or sets a value indicating whether this instance can seek.
  @JsonKey(name: 'CanSeek')
  final bool? canSeek;

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

  /// Gets or sets the index of the audio stream.
  @JsonKey(name: 'AudioStreamIndex')
  final int? audioStreamIndex;

  /// Gets or sets the index of the subtitle stream.
  @JsonKey(name: 'SubtitleStreamIndex')
  final int? subtitleStreamIndex;

  /// Gets or sets a value indicating whether this instance is paused.
  @JsonKey(name: 'IsPaused')
  final bool? isPaused;

  /// Gets or sets a value indicating whether this instance is muted.
  @JsonKey(name: 'IsMuted')
  final bool? isMuted;

  /// Gets or sets the position ticks.
  @JsonKey(name: 'PositionTicks')
  final int? positionTicks;
  @JsonKey(name: 'PlaybackStartTimeTicks')
  final int? playbackStartTimeTicks;

  /// Gets or sets the volume level.
  @JsonKey(name: 'VolumeLevel')
  final int? volumeLevel;
  @JsonKey(name: 'Brightness')
  final int? brightness;
  @JsonKey(name: 'AspectRatio')
  final String? aspectRatio;

  /// Gets or sets the play method.
  @JsonKey(name: 'PlayMethod')
  final PlaybackStartInfoPlayMethod? playMethod;

  /// Gets or sets the live stream identifier.
  @JsonKey(name: 'LiveStreamId')
  final String? liveStreamId;

  /// Gets or sets the play session identifier.
  @JsonKey(name: 'PlaySessionId')
  final String? playSessionId;

  /// Gets or sets the repeat mode.
  @JsonKey(name: 'RepeatMode')
  final PlaybackStartInfoRepeatMode? repeatMode;

  /// Gets or sets the playback order.
  @JsonKey(name: 'PlaybackOrder')
  final PlaybackStartInfoPlaybackOrder? playbackOrder;
  @JsonKey(name: 'NowPlayingQueue')
  final List<QueueItem>? nowPlayingQueue;
  @JsonKey(name: 'PlaylistItemId')
  final String? playlistItemId;

  Map<String, Object?> toJson() => _$PlaybackStartInfoToJson(this);
}
