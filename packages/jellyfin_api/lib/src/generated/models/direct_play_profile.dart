// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'direct_play_profile_type.dart';

part 'direct_play_profile.g.dart';

/// Defines the MediaBrowser.Model.Dlna.DirectPlayProfile.
@JsonSerializable()
class DirectPlayProfile {
  const DirectPlayProfile({
    required this.container,
    required this.audioCodec,
    required this.videoCodec,
    required this.type,
  });
  
  factory DirectPlayProfile.fromJson(Map<String, Object?> json) => _$DirectPlayProfileFromJson(json);
  
  /// Gets or sets the container.
  @JsonKey(name: 'Container')
  final String? container;

  /// Gets or sets the audio codec.
  @JsonKey(name: 'AudioCodec')
  final String? audioCodec;

  /// Gets or sets the video codec.
  @JsonKey(name: 'VideoCodec')
  final String? videoCodec;

  /// Gets or sets the Dlna profile type.
  @JsonKey(name: 'Type')
  final DirectPlayProfileType? type;

  Map<String, Object?> toJson() => _$DirectPlayProfileToJson(this);
}
