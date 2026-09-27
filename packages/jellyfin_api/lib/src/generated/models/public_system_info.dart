// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'public_system_info.g.dart';

@JsonSerializable()
class PublicSystemInfo {
  const PublicSystemInfo({
    this.localAddress,
    this.serverName,
    this.version,
    this.productName,
    this.operatingSystem,
    this.id,
    this.startupWizardCompleted,
  });
  
  factory PublicSystemInfo.fromJson(Map<String, Object?> json) => _$PublicSystemInfoFromJson(json);
  
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

  Map<String, Object?> toJson() => _$PublicSystemInfoToJson(this);
}
