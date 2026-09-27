// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SystemInfo _$SystemInfoFromJson(Map<String, dynamic> json) => SystemInfo(
  canSelfRestart: json['CanSelfRestart'] as bool? ?? true,
  canLaunchWebBrowser: json['CanLaunchWebBrowser'] as bool? ?? false,
  hasUpdateAvailable: json['HasUpdateAvailable'] as bool? ?? false,
  encoderLocation: json['EncoderLocation'] as String? ?? 'System',
  systemArchitecture: json['SystemArchitecture'] as String? ?? 'X64',
  localAddress: json['LocalAddress'] as String?,
  serverName: json['ServerName'] as String?,
  version: json['Version'] as String?,
  productName: json['ProductName'] as String?,
  operatingSystem: json['OperatingSystem'] as String?,
  id: json['Id'] as String?,
  startupWizardCompleted: json['StartupWizardCompleted'] as bool?,
  operatingSystemDisplayName: json['OperatingSystemDisplayName'] as String?,
  packageName: json['PackageName'] as String?,
  hasPendingRestart: json['HasPendingRestart'] as bool?,
  isShuttingDown: json['IsShuttingDown'] as bool?,
  supportsLibraryMonitor: json['SupportsLibraryMonitor'] as bool?,
  webSocketPortNumber: (json['WebSocketPortNumber'] as num?)?.toInt(),
  completedInstallations: (json['CompletedInstallations'] as List<dynamic>?)
      ?.map((e) => InstallationInfo.fromJson(e as Map<String, dynamic>))
      .toList(),
  programDataPath: json['ProgramDataPath'] as String?,
  webPath: json['WebPath'] as String?,
  itemsByNamePath: json['ItemsByNamePath'] as String?,
  cachePath: json['CachePath'] as String?,
  logPath: json['LogPath'] as String?,
  internalMetadataPath: json['InternalMetadataPath'] as String?,
  transcodingTempPath: json['TranscodingTempPath'] as String?,
  castReceiverApplications: (json['CastReceiverApplications'] as List<dynamic>?)
      ?.map((e) => CastReceiverApplication.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SystemInfoToJson(SystemInfo instance) =>
    <String, dynamic>{
      'LocalAddress': instance.localAddress,
      'ServerName': instance.serverName,
      'Version': instance.version,
      'ProductName': instance.productName,
      'OperatingSystem': instance.operatingSystem,
      'Id': instance.id,
      'StartupWizardCompleted': instance.startupWizardCompleted,
      'OperatingSystemDisplayName': instance.operatingSystemDisplayName,
      'PackageName': instance.packageName,
      'HasPendingRestart': instance.hasPendingRestart,
      'IsShuttingDown': instance.isShuttingDown,
      'SupportsLibraryMonitor': instance.supportsLibraryMonitor,
      'WebSocketPortNumber': instance.webSocketPortNumber,
      'CompletedInstallations': instance.completedInstallations,
      'CanSelfRestart': instance.canSelfRestart,
      'CanLaunchWebBrowser': instance.canLaunchWebBrowser,
      'ProgramDataPath': instance.programDataPath,
      'WebPath': instance.webPath,
      'ItemsByNamePath': instance.itemsByNamePath,
      'CachePath': instance.cachePath,
      'LogPath': instance.logPath,
      'InternalMetadataPath': instance.internalMetadataPath,
      'TranscodingTempPath': instance.transcodingTempPath,
      'CastReceiverApplications': instance.castReceiverApplications,
      'HasUpdateAvailable': instance.hasUpdateAvailable,
      'EncoderLocation': instance.encoderLocation,
      'SystemArchitecture': instance.systemArchitecture,
    };
