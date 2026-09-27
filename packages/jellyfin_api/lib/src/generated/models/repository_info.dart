// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'repository_info.g.dart';

/// Class RepositoryInfo.
@JsonSerializable()
class RepositoryInfo {
  const RepositoryInfo({
    this.name,
    this.url,
    this.enabled,
  });
  
  factory RepositoryInfo.fromJson(Map<String, Object?> json) => _$RepositoryInfoFromJson(json);
  
  /// Gets or sets the name.
  @JsonKey(name: 'Name')
  final String? name;

  /// Gets or sets the URL.
  @JsonKey(name: 'Url')
  final String? url;

  /// Gets or sets a value indicating whether the repository is enabled.
  @JsonKey(name: 'Enabled')
  final bool? enabled;

  Map<String, Object?> toJson() => _$RepositoryInfoToJson(this);
}
