// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'version_info.g.dart';

/// Defines the MediaBrowser.Model.Updates.VersionInfo class.
@JsonSerializable()
class VersionInfo {
  const VersionInfo({
    this.version,
    this.versionNumber,
    this.changelog,
    this.targetAbi,
    this.sourceUrl,
    this.checksum,
    this.timestamp,
    this.repositoryName,
    this.repositoryUrl,
  });
  
  factory VersionInfo.fromJson(Map<String, Object?> json) => _$VersionInfoFromJson(json);
  
  /// Gets or sets the version.
  final String? version;

  /// Gets the version as a System.Version.
  @JsonKey(name: 'VersionNumber')
  final String? versionNumber;

  /// Gets or sets the changelog for this version.
  final String? changelog;

  /// Gets or sets the ABI that this version was built against.
  final String? targetAbi;

  /// Gets or sets the source URL.
  final String? sourceUrl;

  /// Gets or sets a checksum for the binary.
  final String? checksum;

  /// Gets or sets a timestamp of when the binary was built.
  final String? timestamp;

  /// Gets or sets the repository name.
  final String? repositoryName;

  /// Gets or sets the repository url.
  final String? repositoryUrl;

  Map<String, Object?> toJson() => _$VersionInfoToJson(this);
}
