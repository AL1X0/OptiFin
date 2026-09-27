// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'package_info.dart';

part 'installation_info.g.dart';

/// Class InstallationInfo.
@JsonSerializable()
class InstallationInfo {
  const InstallationInfo({
    required this.guid,
    required this.name,
    required this.version,
    required this.changelog,
    required this.sourceUrl,
    required this.checksum,
    required this.packageInfo,
  });
  
  factory InstallationInfo.fromJson(Map<String, Object?> json) => _$InstallationInfoFromJson(json);
  
  /// Gets or sets the Id.
  @JsonKey(name: 'Guid')
  final String? guid;

  /// Gets or sets the name.
  @JsonKey(name: 'Name')
  final String? name;

  /// Gets or sets the version.
  @JsonKey(name: 'Version')
  final String? version;

  /// Gets or sets the changelog for this version.
  @JsonKey(name: 'Changelog')
  final String? changelog;

  /// Gets or sets the source URL.
  @JsonKey(name: 'SourceUrl')
  final String? sourceUrl;

  /// Gets or sets a checksum for the binary.
  @JsonKey(name: 'Checksum')
  final String? checksum;

  /// Gets or sets package information for the installation.
  @JsonKey(name: 'PackageInfo')
  final PackageInfo? packageInfo;

  Map<String, Object?> toJson() => _$InstallationInfoToJson(this);
}
