// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'access_schedule.dart';
import 'unrated_item.dart';
import 'user_policy_sync_play_access.dart';

part 'user_policy.g.dart';

@JsonSerializable()
class UserPolicy {
  const UserPolicy({
    required this.authenticationProviderId,
    required this.passwordResetProviderId,
    this.enableSharedDeviceControl,
    this.isHidden,
    this.remoteClientBitrateLimit,
    this.isDisabled,
    this.maxParentalRating,
    this.maxParentalSubRating,
    this.blockedTags,
    this.allowedTags,
    this.enableUserPreferenceAccess,
    this.accessSchedules,
    this.blockUnratedItems,
    this.enableRemoteControlOfOtherUsers,
    this.isAdministrator,
    this.enableRemoteAccess,
    this.enableLiveTvManagement,
    this.enableLiveTvAccess,
    this.enableMediaPlayback,
    this.enableAudioPlaybackTranscoding,
    this.enableVideoPlaybackTranscoding,
    this.enablePlaybackRemuxing,
    this.forceRemoteSourceTranscoding,
    this.enableContentDeletion,
    this.enableContentDeletionFromFolders,
    this.enableContentDownloading,
    this.enableSyncTranscoding,
    this.enableMediaConversion,
    this.syncPlayAccess,
    this.enableAllDevices,
    this.enabledChannels,
    this.enableAllChannels,
    this.enabledFolders,
    this.enableAllFolders,
    this.invalidLoginAttemptCount,
    this.loginAttemptsBeforeLockout,
    this.maxActiveSessions,
    this.enablePublicSharing,
    this.blockedMediaFolders,
    this.blockedChannels,
    this.enabledDevices,
    this.enableSubtitleManagement = false,
    this.enableCollectionManagement = false,
    this.enableLyricManagement = false,
  });
  
  factory UserPolicy.fromJson(Map<String, Object?> json) => _$UserPolicyFromJson(json);
  
  /// Gets or sets a value indicating whether this instance is administrator.
  @JsonKey(name: 'IsAdministrator')
  final bool? isAdministrator;

  /// Gets or sets a value indicating whether this instance is hidden.
  @JsonKey(name: 'IsHidden')
  final bool? isHidden;

  /// Gets or sets a value indicating whether this instance can manage collections.
  @JsonKey(name: 'EnableCollectionManagement')
  final bool enableCollectionManagement;

  /// Gets or sets a value indicating whether this instance can manage subtitles.
  @JsonKey(name: 'EnableSubtitleManagement')
  final bool enableSubtitleManagement;

  /// Gets or sets a value indicating whether this user can manage lyrics.
  @JsonKey(name: 'EnableLyricManagement')
  final bool enableLyricManagement;

  /// Gets or sets a value indicating whether this instance is disabled.
  @JsonKey(name: 'IsDisabled')
  final bool? isDisabled;

  /// Gets or sets the max parental rating.
  @JsonKey(name: 'MaxParentalRating')
  final int? maxParentalRating;
  @JsonKey(name: 'MaxParentalSubRating')
  final int? maxParentalSubRating;
  @JsonKey(name: 'BlockedTags')
  final List<String>? blockedTags;
  @JsonKey(name: 'AllowedTags')
  final List<String>? allowedTags;
  @JsonKey(name: 'EnableUserPreferenceAccess')
  final bool? enableUserPreferenceAccess;
  @JsonKey(name: 'AccessSchedules')
  final List<AccessSchedule>? accessSchedules;
  @JsonKey(name: 'BlockUnratedItems')
  final List<UnratedItem>? blockUnratedItems;
  @JsonKey(name: 'EnableRemoteControlOfOtherUsers')
  final bool? enableRemoteControlOfOtherUsers;
  @JsonKey(name: 'EnableSharedDeviceControl')
  final bool? enableSharedDeviceControl;
  @JsonKey(name: 'EnableRemoteAccess')
  final bool? enableRemoteAccess;
  @JsonKey(name: 'EnableLiveTvManagement')
  final bool? enableLiveTvManagement;
  @JsonKey(name: 'EnableLiveTvAccess')
  final bool? enableLiveTvAccess;
  @JsonKey(name: 'EnableMediaPlayback')
  final bool? enableMediaPlayback;
  @JsonKey(name: 'EnableAudioPlaybackTranscoding')
  final bool? enableAudioPlaybackTranscoding;
  @JsonKey(name: 'EnableVideoPlaybackTranscoding')
  final bool? enableVideoPlaybackTranscoding;
  @JsonKey(name: 'EnablePlaybackRemuxing')
  final bool? enablePlaybackRemuxing;
  @JsonKey(name: 'ForceRemoteSourceTranscoding')
  final bool? forceRemoteSourceTranscoding;
  @JsonKey(name: 'EnableContentDeletion')
  final bool? enableContentDeletion;
  @JsonKey(name: 'EnableContentDeletionFromFolders')
  final List<String>? enableContentDeletionFromFolders;
  @JsonKey(name: 'EnableContentDownloading')
  final bool? enableContentDownloading;

  /// Gets or sets a value indicating whether [enable synchronize].
  @JsonKey(name: 'EnableSyncTranscoding')
  final bool? enableSyncTranscoding;
  @JsonKey(name: 'EnableMediaConversion')
  final bool? enableMediaConversion;
  @JsonKey(name: 'EnabledDevices')
  final List<String>? enabledDevices;
  @JsonKey(name: 'EnableAllDevices')
  final bool? enableAllDevices;
  @JsonKey(name: 'EnabledChannels')
  final List<String>? enabledChannels;
  @JsonKey(name: 'EnableAllChannels')
  final bool? enableAllChannels;
  @JsonKey(name: 'EnabledFolders')
  final List<String>? enabledFolders;
  @JsonKey(name: 'EnableAllFolders')
  final bool? enableAllFolders;
  @JsonKey(name: 'InvalidLoginAttemptCount')
  final int? invalidLoginAttemptCount;
  @JsonKey(name: 'LoginAttemptsBeforeLockout')
  final int? loginAttemptsBeforeLockout;
  @JsonKey(name: 'MaxActiveSessions')
  final int? maxActiveSessions;
  @JsonKey(name: 'EnablePublicSharing')
  final bool? enablePublicSharing;
  @JsonKey(name: 'BlockedMediaFolders')
  final List<String>? blockedMediaFolders;
  @JsonKey(name: 'BlockedChannels')
  final List<String>? blockedChannels;
  @JsonKey(name: 'RemoteClientBitrateLimit')
  final int? remoteClientBitrateLimit;
  @JsonKey(name: 'AuthenticationProviderId')
  final String authenticationProviderId;
  @JsonKey(name: 'PasswordResetProviderId')
  final String passwordResetProviderId;

  /// Enum SyncPlayUserAccessType.
  @JsonKey(name: 'SyncPlayAccess')
  final UserPolicySyncPlayAccess? syncPlayAccess;

  Map<String, Object?> toJson() => _$UserPolicyToJson(this);
}
