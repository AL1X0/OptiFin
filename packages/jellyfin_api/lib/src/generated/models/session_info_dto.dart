// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'base_item_dto.dart';
import 'client_capabilities_dto.dart';
import 'general_command_type.dart';
import 'media_type.dart';
import 'player_state_info.dart';
import 'queue_item.dart';
import 'session_user_info.dart';
import 'transcoding_info.dart';

part 'session_info_dto.g.dart';

/// Session info DTO.
@JsonSerializable()
class SessionInfoDto {
  const SessionInfoDto({
    required this.playState,
    required this.additionalUsers,
    required this.capabilities,
    required this.remoteEndPoint,
    required this.playableMediaTypes,
    required this.id,
    required this.userId,
    required this.userName,
    required this.client,
    required this.lastActivityDate,
    required this.lastPlaybackCheckIn,
    required this.lastPausedDate,
    required this.deviceName,
    required this.deviceType,
    required this.nowPlayingItem,
    required this.nowViewingItem,
    required this.deviceId,
    required this.applicationVersion,
    required this.transcodingInfo,
    required this.isActive,
    required this.supportsMediaControl,
    required this.supportsRemoteControl,
    required this.nowPlayingQueue,
    required this.hasCustomDeviceName,
    required this.playlistItemId,
    required this.serverId,
    required this.userPrimaryImageTag,
    required this.supportedCommands,
  });
  
  factory SessionInfoDto.fromJson(Map<String, Object?> json) => _$SessionInfoDtoFromJson(json);
  
  /// Gets or sets the play state.
  @JsonKey(name: 'PlayState')
  final PlayerStateInfo? playState;

  /// Gets or sets the additional users.
  @JsonKey(name: 'AdditionalUsers')
  final List<SessionUserInfo>? additionalUsers;

  /// Gets or sets the client capabilities.
  @JsonKey(name: 'Capabilities')
  final ClientCapabilitiesDto? capabilities;

  /// Gets or sets the remote end point.
  @JsonKey(name: 'RemoteEndPoint')
  final String? remoteEndPoint;

  /// Gets or sets the playable media types.
  @JsonKey(name: 'PlayableMediaTypes')
  final List<MediaType>? playableMediaTypes;

  /// Gets or sets the id.
  @JsonKey(name: 'Id')
  final String? id;

  /// Gets or sets the user id.
  @JsonKey(name: 'UserId')
  final String? userId;

  /// Gets or sets the username.
  @JsonKey(name: 'UserName')
  final String? userName;

  /// Gets or sets the type of the client.
  @JsonKey(name: 'Client')
  final String? client;

  /// Gets or sets the last activity date.
  @JsonKey(name: 'LastActivityDate')
  final DateTime? lastActivityDate;

  /// Gets or sets the last playback check in.
  @JsonKey(name: 'LastPlaybackCheckIn')
  final DateTime? lastPlaybackCheckIn;

  /// Gets or sets the last paused date.
  @JsonKey(name: 'LastPausedDate')
  final DateTime? lastPausedDate;

  /// Gets or sets the name of the device.
  @JsonKey(name: 'DeviceName')
  final String? deviceName;

  /// Gets or sets the type of the device.
  @JsonKey(name: 'DeviceType')
  final String? deviceType;

  /// Gets or sets the now playing item.
  @JsonKey(name: 'NowPlayingItem')
  final BaseItemDto? nowPlayingItem;

  /// Gets or sets the now viewing item.
  @JsonKey(name: 'NowViewingItem')
  final BaseItemDto? nowViewingItem;

  /// Gets or sets the device id.
  @JsonKey(name: 'DeviceId')
  final String? deviceId;

  /// Gets or sets the application version.
  @JsonKey(name: 'ApplicationVersion')
  final String? applicationVersion;

  /// Gets or sets the transcoding info.
  @JsonKey(name: 'TranscodingInfo')
  final TranscodingInfo? transcodingInfo;

  /// Gets or sets a value indicating whether this session is active.
  @JsonKey(name: 'IsActive')
  final bool? isActive;

  /// Gets or sets a value indicating whether the session supports media control.
  @JsonKey(name: 'SupportsMediaControl')
  final bool? supportsMediaControl;

  /// Gets or sets a value indicating whether the session supports remote control.
  @JsonKey(name: 'SupportsRemoteControl')
  final bool? supportsRemoteControl;

  /// Gets or sets the now playing queue.
  @JsonKey(name: 'NowPlayingQueue')
  final List<QueueItem>? nowPlayingQueue;

  /// Gets or sets a value indicating whether this session has a custom device name.
  @JsonKey(name: 'HasCustomDeviceName')
  final bool? hasCustomDeviceName;

  /// Gets or sets the playlist item id.
  @JsonKey(name: 'PlaylistItemId')
  final String? playlistItemId;

  /// Gets or sets the server id.
  @JsonKey(name: 'ServerId')
  final String? serverId;

  /// Gets or sets the user primary image tag.
  @JsonKey(name: 'UserPrimaryImageTag')
  final String? userPrimaryImageTag;

  /// Gets or sets the supported commands.
  @JsonKey(name: 'SupportedCommands')
  final List<GeneralCommandType>? supportedCommands;

  Map<String, Object?> toJson() => _$SessionInfoDtoToJson(this);
}
