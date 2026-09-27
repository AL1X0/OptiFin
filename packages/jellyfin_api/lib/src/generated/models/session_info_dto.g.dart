// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_info_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionInfoDto _$SessionInfoDtoFromJson(
  Map<String, dynamic> json,
) => SessionInfoDto(
  playState: json['PlayState'] == null
      ? null
      : PlayerStateInfo.fromJson(json['PlayState'] as Map<String, dynamic>),
  additionalUsers: (json['AdditionalUsers'] as List<dynamic>?)
      ?.map((e) => SessionUserInfo.fromJson(e as Map<String, dynamic>))
      .toList(),
  capabilities: json['Capabilities'] == null
      ? null
      : ClientCapabilitiesDto.fromJson(
          json['Capabilities'] as Map<String, dynamic>,
        ),
  remoteEndPoint: json['RemoteEndPoint'] as String?,
  playableMediaTypes: (json['PlayableMediaTypes'] as List<dynamic>?)
      ?.map(MediaType.fromJson)
      .toList(),
  id: json['Id'] as String?,
  userId: json['UserId'] as String?,
  userName: json['UserName'] as String?,
  client: json['Client'] as String?,
  lastActivityDate: json['LastActivityDate'] == null
      ? null
      : DateTime.parse(json['LastActivityDate'] as String),
  lastPlaybackCheckIn: json['LastPlaybackCheckIn'] == null
      ? null
      : DateTime.parse(json['LastPlaybackCheckIn'] as String),
  lastPausedDate: json['LastPausedDate'] == null
      ? null
      : DateTime.parse(json['LastPausedDate'] as String),
  deviceName: json['DeviceName'] as String?,
  deviceType: json['DeviceType'] as String?,
  nowPlayingItem: json['NowPlayingItem'] == null
      ? null
      : BaseItemDto.fromJson(json['NowPlayingItem'] as Map<String, dynamic>),
  nowViewingItem: json['NowViewingItem'] == null
      ? null
      : BaseItemDto.fromJson(json['NowViewingItem'] as Map<String, dynamic>),
  deviceId: json['DeviceId'] as String?,
  applicationVersion: json['ApplicationVersion'] as String?,
  transcodingInfo: json['TranscodingInfo'] == null
      ? null
      : TranscodingInfo.fromJson(
          json['TranscodingInfo'] as Map<String, dynamic>,
        ),
  isActive: json['IsActive'] as bool?,
  supportsMediaControl: json['SupportsMediaControl'] as bool?,
  supportsRemoteControl: json['SupportsRemoteControl'] as bool?,
  nowPlayingQueue: (json['NowPlayingQueue'] as List<dynamic>?)
      ?.map((e) => QueueItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  hasCustomDeviceName: json['HasCustomDeviceName'] as bool?,
  playlistItemId: json['PlaylistItemId'] as String?,
  serverId: json['ServerId'] as String?,
  userPrimaryImageTag: json['UserPrimaryImageTag'] as String?,
  supportedCommands: (json['SupportedCommands'] as List<dynamic>?)
      ?.map((e) => GeneralCommandType.fromJson(e as String))
      .toList(),
);

Map<String, dynamic> _$SessionInfoDtoToJson(SessionInfoDto instance) =>
    <String, dynamic>{
      'PlayState': ?instance.playState,
      'AdditionalUsers': ?instance.additionalUsers,
      'Capabilities': ?instance.capabilities,
      'RemoteEndPoint': ?instance.remoteEndPoint,
      'PlayableMediaTypes': ?instance.playableMediaTypes,
      'Id': ?instance.id,
      'UserId': ?instance.userId,
      'UserName': ?instance.userName,
      'Client': ?instance.client,
      'LastActivityDate': ?instance.lastActivityDate?.toIso8601String(),
      'LastPlaybackCheckIn': ?instance.lastPlaybackCheckIn?.toIso8601String(),
      'LastPausedDate': ?instance.lastPausedDate?.toIso8601String(),
      'DeviceName': ?instance.deviceName,
      'DeviceType': ?instance.deviceType,
      'NowPlayingItem': ?instance.nowPlayingItem,
      'NowViewingItem': ?instance.nowViewingItem,
      'DeviceId': ?instance.deviceId,
      'ApplicationVersion': ?instance.applicationVersion,
      'TranscodingInfo': ?instance.transcodingInfo,
      'IsActive': ?instance.isActive,
      'SupportsMediaControl': ?instance.supportsMediaControl,
      'SupportsRemoteControl': ?instance.supportsRemoteControl,
      'NowPlayingQueue': ?instance.nowPlayingQueue,
      'HasCustomDeviceName': ?instance.hasCustomDeviceName,
      'PlaylistItemId': ?instance.playlistItemId,
      'ServerId': ?instance.serverId,
      'UserPrimaryImageTag': ?instance.userPrimaryImageTag,
      'SupportedCommands': ?instance.supportedCommands,
    };
