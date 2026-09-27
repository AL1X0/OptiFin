// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'player_state_info_play_method.dart';
import 'player_state_info_playback_order.dart';
import 'player_state_info_repeat_mode.dart';

part 'player_state_info.g.dart';

@JsonSerializable()
class PlayerStateInfo {
  const PlayerStateInfo({
    required this.positionTicks,
    required this.canSeek,
    required this.isPaused,
    required this.isMuted,
    required this.volumeLevel,
    required this.audioStreamIndex,
    required this.subtitleStreamIndex,
    required this.mediaSourceId,
    required this.playMethod,
    required this.repeatMode,
    required this.playbackOrder,
    required this.liveStreamId,
  });
  
  factory PlayerStateInfo.fromJson(Map<String, Object?> json) => _$PlayerStateInfoFromJson(json);
  
  /// Gets or sets the now playing position ticks.
  @JsonKey(name: 'PositionTicks')
  final int? positionTicks;

  /// Gets or sets a value indicating whether this instance can seek.
  @JsonKey(name: 'CanSeek')
  final bool? canSeek;

  /// Gets or sets a value indicating whether this instance is paused.
  @JsonKey(name: 'IsPaused')
  final bool? isPaused;

  /// Gets or sets a value indicating whether this instance is muted.
  @JsonKey(name: 'IsMuted')
  final bool? isMuted;

  /// Gets or sets the volume level.
  @JsonKey(name: 'VolumeLevel')
  final int? volumeLevel;

  /// Gets or sets the index of the now playing audio stream.
  @JsonKey(name: 'AudioStreamIndex')
  final int? audioStreamIndex;

  /// Gets or sets the index of the now playing subtitle stream.
  @JsonKey(name: 'SubtitleStreamIndex')
  final int? subtitleStreamIndex;

  /// Gets or sets the now playing media version identifier.
  @JsonKey(name: 'MediaSourceId')
  final String? mediaSourceId;

  /// Gets or sets the play method.
  @JsonKey(name: 'PlayMethod')
  final PlayerStateInfoPlayMethod? playMethod;

  /// Gets or sets the repeat mode.
  @JsonKey(name: 'RepeatMode')
  final PlayerStateInfoRepeatMode? repeatMode;

  /// Gets or sets the playback order.
  @JsonKey(name: 'PlaybackOrder')
  final PlayerStateInfoPlaybackOrder? playbackOrder;

  /// Gets or sets the now playing live stream identifier.
  @JsonKey(name: 'LiveStreamId')
  final String? liveStreamId;

  Map<String, Object?> toJson() => _$PlayerStateInfoToJson(this);
}
