// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'cast_receiver_application.dart';
import 'metadata_options.dart';
import 'name_value_pair.dart';
import 'path_substitution.dart';
import 'repository_info.dart';
import 'server_configuration_chapter_image_resolution.dart';
import 'server_configuration_image_saving_convention.dart';
import 'trickplay_options.dart';

part 'server_configuration.g.dart';

/// Represents the server configuration.
@JsonSerializable()
class ServerConfiguration {
  const ServerConfiguration({
    required this.maxResumePct,
    required this.isStartupWizardCompleted,
    required this.cachePath,
    required this.previousVersion,
    required this.previousVersionStr,
    required this.enableMetrics,
    required this.enableNormalizedItemByNameIds,
    required this.isPortAuthorized,
    required this.quickConnectAvailable,
    required this.enableCaseSensitiveItemIds,
    required this.disableLiveTvChannelUserDataName,
    required this.metadataPath,
    required this.preferredMetadataLanguage,
    required this.metadataCountryCode,
    required this.sortReplaceCharacters,
    required this.sortRemoveCharacters,
    required this.sortRemoveWords,
    required this.minResumePct,
    required this.logFileRetentionDays,
    required this.minResumeDurationSeconds,
    required this.minAudiobookResume,
    required this.maxAudiobookResume,
    required this.inactiveSessionThreshold,
    required this.libraryMonitorDelay,
    required this.libraryUpdateDuration,
    required this.cacheSize,
    required this.imageSavingConvention,
    required this.metadataOptions,
    required this.skipDeserializationForBasicTypes,
    required this.serverName,
    required this.uiCulture,
    required this.saveMetadataHidden,
    required this.contentTypes,
    required this.remoteClientBitrateLimit,
    required this.enableFolderView,
    required this.enableGroupingMoviesIntoCollections,
    required this.enableLegacyAuthorization,
    required this.displaySpecialsWithinSeasons,
    required this.codecsUsed,
    required this.pluginRepositories,
    required this.enableExternalContentInSuggestions,
    required this.imageExtractionTimeoutMs,
    required this.pathSubstitutions,
    required this.enableSlowResponseWarning,
    required this.slowResponseThresholdMs,
    required this.corsHosts,
    required this.activityLogRetentionDays,
    required this.libraryScanFanoutConcurrency,
    required this.libraryMetadataRefreshConcurrency,
    required this.allowClientLogUpload,
    required this.dummyChapterDuration,
    required this.chapterImageResolution,
    required this.parallelImageEncodingLimit,
    required this.castReceiverApplications,
    required this.trickplayOptions,
    required this.enableGroupingShowsIntoCollections,
  });
  
  factory ServerConfiguration.fromJson(Map<String, Object?> json) => _$ServerConfigurationFromJson(json);
  
  /// Gets or sets the number of days we should retain log files.
  @JsonKey(name: 'LogFileRetentionDays')
  final int logFileRetentionDays;

  /// Gets or sets a value indicating whether this instance is first run.
  @JsonKey(name: 'IsStartupWizardCompleted')
  final bool isStartupWizardCompleted;

  /// Gets or sets the cache path.
  @JsonKey(name: 'CachePath')
  final String? cachePath;

  /// Gets or sets the last known version that was ran using the configuration.
  @JsonKey(name: 'PreviousVersion')
  final String? previousVersion;

  /// Gets or sets the stringified PreviousVersion to be stored/loaded,.
  /// because System.Version itself isn't xml-serializable.
  @JsonKey(name: 'PreviousVersionStr')
  final String? previousVersionStr;

  /// Gets or sets a value indicating whether to enable prometheus metrics exporting.
  @JsonKey(name: 'EnableMetrics')
  final bool enableMetrics;
  @JsonKey(name: 'EnableNormalizedItemByNameIds')
  final bool enableNormalizedItemByNameIds;

  /// Gets or sets a value indicating whether this instance is port authorized.
  @JsonKey(name: 'IsPortAuthorized')
  final bool isPortAuthorized;

  /// Gets or sets a value indicating whether quick connect is available for use on this server.
  @JsonKey(name: 'QuickConnectAvailable')
  final bool quickConnectAvailable;

  /// Gets or sets a value indicating whether [enable case-sensitive item ids].
  @JsonKey(name: 'EnableCaseSensitiveItemIds')
  final bool enableCaseSensitiveItemIds;
  @JsonKey(name: 'DisableLiveTvChannelUserDataName')
  final bool disableLiveTvChannelUserDataName;

  /// Gets or sets the metadata path.
  @JsonKey(name: 'MetadataPath')
  final String metadataPath;

  /// Gets or sets the preferred metadata language.
  @JsonKey(name: 'PreferredMetadataLanguage')
  final String preferredMetadataLanguage;

  /// Gets or sets the metadata country code.
  @JsonKey(name: 'MetadataCountryCode')
  final String metadataCountryCode;

  /// Gets or sets characters to be replaced with a ' ' in strings to create a sort name.
  @JsonKey(name: 'SortReplaceCharacters')
  final List<String> sortReplaceCharacters;

  /// Gets or sets characters to be removed from strings to create a sort name.
  @JsonKey(name: 'SortRemoveCharacters')
  final List<String> sortRemoveCharacters;

  /// Gets or sets words to be removed from strings to create a sort name.
  @JsonKey(name: 'SortRemoveWords')
  final List<String> sortRemoveWords;

  /// Gets or sets the minimum percentage of an item that must be played in order for playstate to be updated.
  @JsonKey(name: 'MinResumePct')
  final int minResumePct;

  /// Gets or sets the maximum percentage of an item that can be played while still saving playstate. If this percentage is crossed playstate will be reset to the beginning and the item will be marked watched.
  @JsonKey(name: 'MaxResumePct')
  final int maxResumePct;

  /// Gets or sets the minimum duration that an item must have in order to be eligible for playstate updates..
  @JsonKey(name: 'MinResumeDurationSeconds')
  final int minResumeDurationSeconds;

  /// Gets or sets the minimum minutes of a book that must be played in order for playstate to be updated.
  @JsonKey(name: 'MinAudiobookResume')
  final int minAudiobookResume;

  /// Gets or sets the remaining minutes of a book that can be played while still saving playstate. If this percentage is crossed playstate will be reset to the beginning and the item will be marked watched.
  @JsonKey(name: 'MaxAudiobookResume')
  final int maxAudiobookResume;

  /// Gets or sets the threshold in minutes after a inactive session gets closed automatically.
  /// If set to 0 the check for inactive sessions gets disabled.
  @JsonKey(name: 'InactiveSessionThreshold')
  final int inactiveSessionThreshold;

  /// Gets or sets the delay in seconds that we will wait after a file system change to try and discover what has been added/removed.
  /// Some delay is necessary with some items because their creation is not atomic.  It involves the creation of several.
  /// different directories and files.
  @JsonKey(name: 'LibraryMonitorDelay')
  final int libraryMonitorDelay;

  /// Gets or sets the duration in seconds that we will wait after a library updated event before executing the library changed notification.
  @JsonKey(name: 'LibraryUpdateDuration')
  final int libraryUpdateDuration;

  /// Gets or sets the maximum amount of items to cache.
  @JsonKey(name: 'CacheSize')
  final int cacheSize;

  /// Gets or sets the image saving convention.
  @JsonKey(name: 'ImageSavingConvention')
  final ServerConfigurationImageSavingConvention imageSavingConvention;
  @JsonKey(name: 'MetadataOptions')
  final List<MetadataOptions> metadataOptions;
  @JsonKey(name: 'SkipDeserializationForBasicTypes')
  final bool skipDeserializationForBasicTypes;
  @JsonKey(name: 'ServerName')
  final String serverName;
  @JsonKey(name: 'UICulture')
  final String uiCulture;
  @JsonKey(name: 'SaveMetadataHidden')
  final bool saveMetadataHidden;
  @JsonKey(name: 'ContentTypes')
  final List<NameValuePair> contentTypes;
  @JsonKey(name: 'RemoteClientBitrateLimit')
  final int remoteClientBitrateLimit;
  @JsonKey(name: 'EnableFolderView')
  final bool enableFolderView;
  @JsonKey(name: 'EnableGroupingMoviesIntoCollections')
  final bool enableGroupingMoviesIntoCollections;
  @JsonKey(name: 'EnableGroupingShowsIntoCollections')
  final bool enableGroupingShowsIntoCollections;
  @JsonKey(name: 'DisplaySpecialsWithinSeasons')
  final bool displaySpecialsWithinSeasons;
  @JsonKey(name: 'CodecsUsed')
  final List<String> codecsUsed;
  @JsonKey(name: 'PluginRepositories')
  final List<RepositoryInfo> pluginRepositories;
  @JsonKey(name: 'EnableExternalContentInSuggestions')
  final bool enableExternalContentInSuggestions;
  @JsonKey(name: 'ImageExtractionTimeoutMs')
  final int imageExtractionTimeoutMs;
  @JsonKey(name: 'PathSubstitutions')
  final List<PathSubstitution> pathSubstitutions;

  /// Gets or sets a value indicating whether slow server responses should be logged as a warning.
  @JsonKey(name: 'EnableSlowResponseWarning')
  final bool enableSlowResponseWarning;

  /// Gets or sets the threshold for the slow response time warning in ms.
  @JsonKey(name: 'SlowResponseThresholdMs')
  final int slowResponseThresholdMs;

  /// Gets or sets the cors hosts.
  @JsonKey(name: 'CorsHosts')
  final List<String> corsHosts;

  /// Gets or sets the number of days we should retain activity logs.
  @JsonKey(name: 'ActivityLogRetentionDays')
  final int? activityLogRetentionDays;

  /// Gets or sets the how the library scan fans out.
  @JsonKey(name: 'LibraryScanFanoutConcurrency')
  final int libraryScanFanoutConcurrency;

  /// Gets or sets the how many metadata refreshes can run concurrently.
  @JsonKey(name: 'LibraryMetadataRefreshConcurrency')
  final int libraryMetadataRefreshConcurrency;

  /// Gets or sets a value indicating whether clients should be allowed to upload logs.
  @JsonKey(name: 'AllowClientLogUpload')
  final bool allowClientLogUpload;

  /// Gets or sets the dummy chapter duration in seconds, use 0 (zero) or less to disable generation altogether.
  @JsonKey(name: 'DummyChapterDuration')
  final int dummyChapterDuration;

  /// Gets or sets the chapter image resolution.
  @JsonKey(name: 'ChapterImageResolution')
  final ServerConfigurationChapterImageResolution chapterImageResolution;

  /// Gets or sets the limit for parallel image encoding.
  @JsonKey(name: 'ParallelImageEncodingLimit')
  final int parallelImageEncodingLimit;

  /// Gets or sets the list of cast receiver applications.
  @JsonKey(name: 'CastReceiverApplications')
  final List<CastReceiverApplication> castReceiverApplications;

  /// Gets or sets the trickplay options.
  @JsonKey(name: 'TrickplayOptions')
  final TrickplayOptions trickplayOptions;

  /// Gets or sets a value indicating whether old authorization methods are allowed.
  @JsonKey(name: 'EnableLegacyAuthorization')
  final bool enableLegacyAuthorization;

  Map<String, Object?> toJson() => _$ServerConfigurationToJson(this);
}
