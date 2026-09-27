// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'version_info.dart';

part 'package_info.g.dart';

/// Class PackageInfo.
@JsonSerializable()
class PackageInfo {
  const PackageInfo({
    this.name,
    this.description,
    this.overview,
    this.owner,
    this.category,
    this.guid,
    this.versions,
    this.imageUrl,
  });
  
  factory PackageInfo.fromJson(Map<String, Object?> json) => _$PackageInfoFromJson(json);
  
  /// Gets or sets the name.
  final String? name;

  /// Gets or sets a long description of the plugin containing features or helpful explanations.
  final String? description;

  /// Gets or sets a short overview of what the plugin does.
  final String? overview;

  /// Gets or sets the owner.
  final String? owner;

  /// Gets or sets the category.
  final String? category;

  /// Gets or sets the guid of the assembly associated with this plugin.
  /// This is used to identify the proper item for automatic updates.
  final String? guid;

  /// Gets or sets the versions.
  final List<VersionInfo>? versions;

  /// Gets or sets the image url for the package.
  final String? imageUrl;

  Map<String, Object?> toJson() => _$PackageInfoToJson(this);
}
