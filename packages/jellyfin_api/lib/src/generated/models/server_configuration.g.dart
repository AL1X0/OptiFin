// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_configuration.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServerConfiguration _$ServerConfigurationFromJson(
  Map<String, dynamic> json,
) => ServerConfiguration(
  maxResumePct: (json['MaxResumePct'] as num).toInt(),
  isStartupWizardCompleted: json['IsStartupWizardCompleted'] as bool,
  cachePath: json['CachePath'] as String?,
  previousVersion: json['PreviousVersion'] as String?,
  previousVersionStr: json['PreviousVersionStr'] as String?,
  enableMetrics: json['EnableMetrics'] as bool,
  enableNormalizedItemByNameIds: json['EnableNormalizedItemByNameIds'] as bool,
  isPortAuthorized: json['IsPortAuthorized'] as bool,
  quickConnectAvailable: json['QuickConnectAvailable'] as bool,
  enableCaseSensitiveItemIds: json['EnableCaseSensitiveItemIds'] as bool,
  disableLiveTvChannelUserDataName:
      json['DisableLiveTvChannelUserDataName'] as bool,
  metadataPath: json['MetadataPath'] as String,
  preferredMetadataLanguage: json['PreferredMetadataLanguage'] as String,
  metadataCountryCode: json['MetadataCountryCode'] as String,
  sortReplaceCharacters: (json['SortReplaceCharacters'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  sortRemoveCharacters: (json['SortRemoveCharacters'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  sortRemoveWords: (json['SortRemoveWords'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  minResumePct: (json['MinResumePct'] as num).toInt(),
  logFileRetentionDays: (json['LogFileRetentionDays'] as num).toInt(),
  minResumeDurationSeconds: (json['MinResumeDurationSeconds'] as num).toInt(),
  minAudiobookResume: (json['MinAudiobookResume'] as num).toInt(),
  maxAudiobookResume: (json['MaxAudiobookResume'] as num).toInt(),
  inactiveSessionThreshold: (json['InactiveSessionThreshold'] as num).toInt(),
  libraryMonitorDelay: (json['LibraryMonitorDelay'] as num).toInt(),
  libraryUpdateDuration: (json['LibraryUpdateDuration'] as num).toInt(),
  cacheSize: (json['CacheSize'] as num).toInt(),
  imageSavingConvention: ServerConfigurationImageSavingConvention.fromJson(
    json['ImageSavingConvention'],
  ),
  metadataOptions: (json['MetadataOptions'] as List<dynamic>)
      .map((e) => MetadataOptions.fromJson(e as Map<String, dynamic>))
      .toList(),
  skipDeserializationForBasicTypes:
      json['SkipDeserializationForBasicTypes'] as bool,
  serverName: json['ServerName'] as String,
  uiCulture: json['UICulture'] as String,
  saveMetadataHidden: json['SaveMetadataHidden'] as bool,
  contentTypes: (json['ContentTypes'] as List<dynamic>)
      .map((e) => NameValuePair.fromJson(e as Map<String, dynamic>))
      .toList(),
  remoteClientBitrateLimit: (json['RemoteClientBitrateLimit'] as num).toInt(),
  enableFolderView: json['EnableFolderView'] as bool,
  enableGroupingMoviesIntoCollections:
      json['EnableGroupingMoviesIntoCollections'] as bool,
  enableLegacyAuthorization: json['EnableLegacyAuthorization'] as bool,
  displaySpecialsWithinSeasons: json['DisplaySpecialsWithinSeasons'] as bool,
  codecsUsed: (json['CodecsUsed'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  pluginRepositories: (json['PluginRepositories'] as List<dynamic>)
      .map((e) => RepositoryInfo.fromJson(e as Map<String, dynamic>))
      .toList(),
  enableExternalContentInSuggestions:
      json['EnableExternalContentInSuggestions'] as bool,
  imageExtractionTimeoutMs: (json['ImageExtractionTimeoutMs'] as num).toInt(),
  pathSubstitutions: (json['PathSubstitutions'] as List<dynamic>)
      .map((e) => PathSubstitution.fromJson(e as Map<String, dynamic>))
      .toList(),
  enableSlowResponseWarning: json['EnableSlowResponseWarning'] as bool,
  slowResponseThresholdMs: (json['SlowResponseThresholdMs'] as num).toInt(),
  corsHosts: (json['CorsHosts'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  activityLogRetentionDays: (json['ActivityLogRetentionDays'] as num?)?.toInt(),
  libraryScanFanoutConcurrency: (json['LibraryScanFanoutConcurrency'] as num)
      .toInt(),
  libraryMetadataRefreshConcurrency:
      (json['LibraryMetadataRefreshConcurrency'] as num).toInt(),
  allowClientLogUpload: json['AllowClientLogUpload'] as bool,
  dummyChapterDuration: (json['DummyChapterDuration'] as num).toInt(),
  chapterImageResolution: ServerConfigurationChapterImageResolution.fromJson(
    json['ChapterImageResolution'],
  ),
  parallelImageEncodingLimit: (json['ParallelImageEncodingLimit'] as num)
      .toInt(),
  castReceiverApplications: (json['CastReceiverApplications'] as List<dynamic>)
      .map((e) => CastReceiverApplication.fromJson(e as Map<String, dynamic>))
      .toList(),
  trickplayOptions: TrickplayOptions.fromJson(
    json['TrickplayOptions'] as Map<String, dynamic>,
  ),
  enableGroupingShowsIntoCollections:
      json['EnableGroupingShowsIntoCollections'] as bool,
);

Map<String, dynamic> _$ServerConfigurationToJson(
  ServerConfiguration instance,
) => <String, dynamic>{
  'LogFileRetentionDays': instance.logFileRetentionDays,
  'IsStartupWizardCompleted': instance.isStartupWizardCompleted,
  'CachePath': instance.cachePath,
  'PreviousVersion': instance.previousVersion,
  'PreviousVersionStr': instance.previousVersionStr,
  'EnableMetrics': instance.enableMetrics,
  'EnableNormalizedItemByNameIds': instance.enableNormalizedItemByNameIds,
  'IsPortAuthorized': instance.isPortAuthorized,
  'QuickConnectAvailable': instance.quickConnectAvailable,
  'EnableCaseSensitiveItemIds': instance.enableCaseSensitiveItemIds,
  'DisableLiveTvChannelUserDataName': instance.disableLiveTvChannelUserDataName,
  'MetadataPath': instance.metadataPath,
  'PreferredMetadataLanguage': instance.preferredMetadataLanguage,
  'MetadataCountryCode': instance.metadataCountryCode,
  'SortReplaceCharacters': instance.sortReplaceCharacters,
  'SortRemoveCharacters': instance.sortRemoveCharacters,
  'SortRemoveWords': instance.sortRemoveWords,
  'MinResumePct': instance.minResumePct,
  'MaxResumePct': instance.maxResumePct,
  'MinResumeDurationSeconds': instance.minResumeDurationSeconds,
  'MinAudiobookResume': instance.minAudiobookResume,
  'MaxAudiobookResume': instance.maxAudiobookResume,
  'InactiveSessionThreshold': instance.inactiveSessionThreshold,
  'LibraryMonitorDelay': instance.libraryMonitorDelay,
  'LibraryUpdateDuration': instance.libraryUpdateDuration,
  'CacheSize': instance.cacheSize,
  'ImageSavingConvention': instance.imageSavingConvention,
  'MetadataOptions': instance.metadataOptions,
  'SkipDeserializationForBasicTypes': instance.skipDeserializationForBasicTypes,
  'ServerName': instance.serverName,
  'UICulture': instance.uiCulture,
  'SaveMetadataHidden': instance.saveMetadataHidden,
  'ContentTypes': instance.contentTypes,
  'RemoteClientBitrateLimit': instance.remoteClientBitrateLimit,
  'EnableFolderView': instance.enableFolderView,
  'EnableGroupingMoviesIntoCollections':
      instance.enableGroupingMoviesIntoCollections,
  'EnableGroupingShowsIntoCollections':
      instance.enableGroupingShowsIntoCollections,
  'DisplaySpecialsWithinSeasons': instance.displaySpecialsWithinSeasons,
  'CodecsUsed': instance.codecsUsed,
  'PluginRepositories': instance.pluginRepositories,
  'EnableExternalContentInSuggestions':
      instance.enableExternalContentInSuggestions,
  'ImageExtractionTimeoutMs': instance.imageExtractionTimeoutMs,
  'PathSubstitutions': instance.pathSubstitutions,
  'EnableSlowResponseWarning': instance.enableSlowResponseWarning,
  'SlowResponseThresholdMs': instance.slowResponseThresholdMs,
  'CorsHosts': instance.corsHosts,
  'ActivityLogRetentionDays': instance.activityLogRetentionDays,
  'LibraryScanFanoutConcurrency': instance.libraryScanFanoutConcurrency,
  'LibraryMetadataRefreshConcurrency':
      instance.libraryMetadataRefreshConcurrency,
  'AllowClientLogUpload': instance.allowClientLogUpload,
  'DummyChapterDuration': instance.dummyChapterDuration,
  'ChapterImageResolution': instance.chapterImageResolution,
  'ParallelImageEncodingLimit': instance.parallelImageEncodingLimit,
  'CastReceiverApplications': instance.castReceiverApplications,
  'TrickplayOptions': instance.trickplayOptions,
  'EnableLegacyAuthorization': instance.enableLegacyAuthorization,
};
