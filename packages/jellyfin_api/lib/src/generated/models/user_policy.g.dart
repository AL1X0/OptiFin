// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_policy.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserPolicy _$UserPolicyFromJson(Map<String, dynamic> json) => UserPolicy(
  enableSharedDeviceControl: json['EnableSharedDeviceControl'] as bool?,
  isHidden: json['IsHidden'] as bool?,
  passwordResetProviderId: json['PasswordResetProviderId'] as String?,
  authenticationProviderId: json['AuthenticationProviderId'] as String?,
  remoteClientBitrateLimit: (json['RemoteClientBitrateLimit'] as num?)?.toInt(),
  isDisabled: json['IsDisabled'] as bool?,
  maxParentalRating: (json['MaxParentalRating'] as num?)?.toInt(),
  maxParentalSubRating: (json['MaxParentalSubRating'] as num?)?.toInt(),
  blockedTags: (json['BlockedTags'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  allowedTags: (json['AllowedTags'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  enableUserPreferenceAccess: json['EnableUserPreferenceAccess'] as bool?,
  accessSchedules: (json['AccessSchedules'] as List<dynamic>?)
      ?.map((e) => AccessSchedule.fromJson(e as Map<String, dynamic>))
      .toList(),
  blockUnratedItems: (json['BlockUnratedItems'] as List<dynamic>?)
      ?.map((e) => UnratedItem.fromJson(e as String))
      .toList(),
  enableRemoteControlOfOtherUsers:
      json['EnableRemoteControlOfOtherUsers'] as bool?,
  isAdministrator: json['IsAdministrator'] as bool?,
  enableRemoteAccess: json['EnableRemoteAccess'] as bool?,
  enableLiveTvManagement: json['EnableLiveTvManagement'] as bool?,
  enableLiveTvAccess: json['EnableLiveTvAccess'] as bool?,
  enableMediaPlayback: json['EnableMediaPlayback'] as bool?,
  enableAudioPlaybackTranscoding:
      json['EnableAudioPlaybackTranscoding'] as bool?,
  enableVideoPlaybackTranscoding:
      json['EnableVideoPlaybackTranscoding'] as bool?,
  enablePlaybackRemuxing: json['EnablePlaybackRemuxing'] as bool?,
  forceRemoteSourceTranscoding: json['ForceRemoteSourceTranscoding'] as bool?,
  enableContentDeletion: json['EnableContentDeletion'] as bool?,
  enableContentDeletionFromFolders:
      (json['EnableContentDeletionFromFolders'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
  enableContentDownloading: json['EnableContentDownloading'] as bool?,
  enableSyncTranscoding: json['EnableSyncTranscoding'] as bool?,
  enableMediaConversion: json['EnableMediaConversion'] as bool?,
  syncPlayAccess: json['SyncPlayAccess'] == null
      ? null
      : UserPolicySyncPlayAccess.fromJson(json['SyncPlayAccess']),
  enableAllDevices: json['EnableAllDevices'] as bool?,
  enabledChannels: (json['EnabledChannels'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  enableAllChannels: json['EnableAllChannels'] as bool?,
  enabledFolders: (json['EnabledFolders'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  enableAllFolders: json['EnableAllFolders'] as bool?,
  invalidLoginAttemptCount: (json['InvalidLoginAttemptCount'] as num?)?.toInt(),
  loginAttemptsBeforeLockout: (json['LoginAttemptsBeforeLockout'] as num?)
      ?.toInt(),
  maxActiveSessions: (json['MaxActiveSessions'] as num?)?.toInt(),
  enablePublicSharing: json['EnablePublicSharing'] as bool?,
  blockedMediaFolders: (json['BlockedMediaFolders'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  blockedChannels: (json['BlockedChannels'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  enabledDevices: (json['EnabledDevices'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  enableSubtitleManagement: json['EnableSubtitleManagement'] as bool? ?? false,
  enableCollectionManagement:
      json['EnableCollectionManagement'] as bool? ?? false,
  enableLyricManagement: json['EnableLyricManagement'] as bool? ?? false,
);

Map<String, dynamic> _$UserPolicyToJson(
  UserPolicy instance,
) => <String, dynamic>{
  'IsAdministrator': instance.isAdministrator,
  'IsHidden': instance.isHidden,
  'EnableCollectionManagement': instance.enableCollectionManagement,
  'EnableSubtitleManagement': instance.enableSubtitleManagement,
  'EnableLyricManagement': instance.enableLyricManagement,
  'IsDisabled': instance.isDisabled,
  'MaxParentalRating': instance.maxParentalRating,
  'MaxParentalSubRating': instance.maxParentalSubRating,
  'BlockedTags': instance.blockedTags,
  'AllowedTags': instance.allowedTags,
  'EnableUserPreferenceAccess': instance.enableUserPreferenceAccess,
  'AccessSchedules': instance.accessSchedules,
  'BlockUnratedItems': instance.blockUnratedItems,
  'EnableRemoteControlOfOtherUsers': instance.enableRemoteControlOfOtherUsers,
  'EnableSharedDeviceControl': instance.enableSharedDeviceControl,
  'EnableRemoteAccess': instance.enableRemoteAccess,
  'EnableLiveTvManagement': instance.enableLiveTvManagement,
  'EnableLiveTvAccess': instance.enableLiveTvAccess,
  'EnableMediaPlayback': instance.enableMediaPlayback,
  'EnableAudioPlaybackTranscoding': instance.enableAudioPlaybackTranscoding,
  'EnableVideoPlaybackTranscoding': instance.enableVideoPlaybackTranscoding,
  'EnablePlaybackRemuxing': instance.enablePlaybackRemuxing,
  'ForceRemoteSourceTranscoding': instance.forceRemoteSourceTranscoding,
  'EnableContentDeletion': instance.enableContentDeletion,
  'EnableContentDeletionFromFolders': instance.enableContentDeletionFromFolders,
  'EnableContentDownloading': instance.enableContentDownloading,
  'EnableSyncTranscoding': instance.enableSyncTranscoding,
  'EnableMediaConversion': instance.enableMediaConversion,
  'EnabledDevices': instance.enabledDevices,
  'EnableAllDevices': instance.enableAllDevices,
  'EnabledChannels': instance.enabledChannels,
  'EnableAllChannels': instance.enableAllChannels,
  'EnabledFolders': instance.enabledFolders,
  'EnableAllFolders': instance.enableAllFolders,
  'InvalidLoginAttemptCount': instance.invalidLoginAttemptCount,
  'LoginAttemptsBeforeLockout': instance.loginAttemptsBeforeLockout,
  'MaxActiveSessions': instance.maxActiveSessions,
  'EnablePublicSharing': instance.enablePublicSharing,
  'BlockedMediaFolders': instance.blockedMediaFolders,
  'BlockedChannels': instance.blockedChannels,
  'RemoteClientBitrateLimit': instance.remoteClientBitrateLimit,
  'AuthenticationProviderId': instance.authenticationProviderId,
  'PasswordResetProviderId': instance.passwordResetProviderId,
  'SyncPlayAccess': instance.syncPlayAccess,
};
