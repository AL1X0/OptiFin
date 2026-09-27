// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'live_tv_service_info_status.dart';

part 'live_tv_service_info.g.dart';

/// Class ServiceInfo.
@JsonSerializable()
class LiveTvServiceInfo {
  const LiveTvServiceInfo({
    required this.name,
    required this.homePageUrl,
    required this.status,
    required this.statusMessage,
    required this.version,
    required this.hasUpdateAvailable,
    required this.isVisible,
    required this.tuners,
  });
  
  factory LiveTvServiceInfo.fromJson(Map<String, Object?> json) => _$LiveTvServiceInfoFromJson(json);
  
  /// Gets or sets the name.
  @JsonKey(name: 'Name')
  final String? name;

  /// Gets or sets the home page URL.
  @JsonKey(name: 'HomePageUrl')
  final String? homePageUrl;

  /// Gets or sets the status.
  @JsonKey(name: 'Status')
  final LiveTvServiceInfoStatus status;

  /// Gets or sets the status message.
  @JsonKey(name: 'StatusMessage')
  final String? statusMessage;

  /// Gets or sets the version.
  @JsonKey(name: 'Version')
  final String? version;

  /// Gets or sets a value indicating whether this instance has update available.
  @JsonKey(name: 'HasUpdateAvailable')
  final bool hasUpdateAvailable;

  /// Gets or sets a value indicating whether this instance is visible.
  @JsonKey(name: 'IsVisible')
  final bool isVisible;
  @JsonKey(name: 'Tuners')
  final List<String>? tuners;

  Map<String, Object?> toJson() => _$LiveTvServiceInfoToJson(this);
}
