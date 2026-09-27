// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'live_tv_service_info.dart';

part 'live_tv_info.g.dart';

@JsonSerializable()
class LiveTvInfo {
  const LiveTvInfo({
    this.services,
    this.isEnabled,
    this.enabledUsers,
  });
  
  factory LiveTvInfo.fromJson(Map<String, Object?> json) => _$LiveTvInfoFromJson(json);
  
  /// Gets or sets the services.
  @JsonKey(name: 'Services')
  final List<LiveTvServiceInfo>? services;

  /// Gets or sets a value indicating whether this instance is enabled.
  @JsonKey(name: 'IsEnabled')
  final bool? isEnabled;

  /// Gets or sets the enabled users.
  @JsonKey(name: 'EnabledUsers')
  final List<String>? enabledUsers;

  Map<String, Object?> toJson() => _$LiveTvInfoToJson(this);
}
