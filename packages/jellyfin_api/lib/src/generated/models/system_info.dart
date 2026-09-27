// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'cast_receiver_application.dart';
import 'installation_info.dart';

part 'system_info.g.dart';

/// Class SystemInfo.
@JsonSerializable()
class SystemInfo {
  const SystemInfo({
    this.canSelfRestart = true,
    this.canLaunchWebBrowser = false,
    this.hasUpdateAvailable = false,
    this.encoderLocation = 'System',
    this.systemArchitecture = 'X64',
    this.localAddress,
    this.serverName,
    this.version,
    this.productName,
    this.operatingSystem,
    this.id,
    this.startupWizardCompleted,
    this.operatingSystemDisplayName,
    this.packageName,
    this.hasPendingRestart,
    this.isShuttingDown,
    this.supportsLibraryMonitor,
    this.webSocketPortNumber,
    this.completedInstallations,
    this.programDataPath,
    this.webPath,
    this.itemsByNamePath,
    this.cachePath,
    this.logPath,
    this.internalMetadataPath,
    this.transcodingTempPath,
    this.castReceiverApplications,
  });
  
  factory SystemInfo.fromJson(Map<String, Object?> json) => _$SystemInfoFromJson(json);
  
  /// Gets or sets the local address.
  @JsonKey(name: 'LocalAddress')
  final String? localAddress;

  /// Gets or sets the name of the server.
  @JsonKey(name: 'ServerName')
  final String? serverName;

  /// Gets or sets the server version.
  @JsonKey(name: 'Version')
  final String? version;

  /// Gets or sets the product name. This is the AssemblyProduct name.
  @JsonKey(name: 'ProductName')
  final String? productName;

  /// Gets or sets the operating system.
  @JsonKey(name: 'OperatingSystem')
  final String? operatingSystem;

  /// Gets or sets the id.
  @JsonKey(name: 'Id')
  final String? id;

  /// Gets or sets a value indicating whether the startup wizard is completed.
  @JsonKey(name: 'StartupWizardCompleted')
  final bool? startupWizardCompleted;

  /// Gets or sets the display name of the operating system.
  @JsonKey(name: 'OperatingSystemDisplayName')
  final String? operatingSystemDisplayName;

  /// Gets or sets the package name.
  @JsonKey(name: 'PackageName')
  final String? packageName;

  /// Gets or sets a value indicating whether this instance has pending restart.
  @JsonKey(name: 'HasPendingRestart')
  final bool? hasPendingRestart;
  @JsonKey(name: 'IsShuttingDown')
  final bool? isShuttingDown;

  /// Gets or sets a value indicating whether [supports library monitor].
  @JsonKey(name: 'SupportsLibraryMonitor')
  final bool? supportsLibraryMonitor;

  /// Gets or sets the web socket port number.
  @JsonKey(name: 'WebSocketPortNumber')
  final int? webSocketPortNumber;

  /// Gets or sets the completed installations.
  @JsonKey(name: 'CompletedInstallations')
  final List<InstallationInfo>? completedInstallations;

  /// Gets or sets a value indicating whether this instance can self restart.
  @JsonKey(name: 'CanSelfRestart')
  final bool canSelfRestart;
  @JsonKey(name: 'CanLaunchWebBrowser')
  final bool canLaunchWebBrowser;

  /// Gets or sets the program data path.
  @JsonKey(name: 'ProgramDataPath')
  final String? programDataPath;

  /// Gets or sets the web UI resources path.
  @JsonKey(name: 'WebPath')
  final String? webPath;

  /// Gets or sets the items by name path.
  @JsonKey(name: 'ItemsByNamePath')
  final String? itemsByNamePath;

  /// Gets or sets the cache path.
  @JsonKey(name: 'CachePath')
  final String? cachePath;

  /// Gets or sets the log path.
  @JsonKey(name: 'LogPath')
  final String? logPath;

  /// Gets or sets the internal metadata path.
  @JsonKey(name: 'InternalMetadataPath')
  final String? internalMetadataPath;

  /// Gets or sets the transcode path.
  @JsonKey(name: 'TranscodingTempPath')
  final String? transcodingTempPath;

  /// Gets or sets the list of cast receiver applications.
  @JsonKey(name: 'CastReceiverApplications')
  final List<CastReceiverApplication>? castReceiverApplications;

  /// Gets or sets a value indicating whether this instance has update available.
  @JsonKey(name: 'HasUpdateAvailable')
  final bool hasUpdateAvailable;
  @JsonKey(name: 'EncoderLocation')
  final String? encoderLocation;
  @JsonKey(name: 'SystemArchitecture')
  final String? systemArchitecture;

  Map<String, Object?> toJson() => _$SystemInfoToJson(this);
}
