// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'subtitle_profile_method.dart';

part 'subtitle_profile.g.dart';

/// A class for subtitle profile information.
@JsonSerializable()
class SubtitleProfile {
  const SubtitleProfile({
    required this.format,
    required this.method,
    required this.didlMode,
    required this.language,
    required this.container,
  });
  
  factory SubtitleProfile.fromJson(Map<String, Object?> json) => _$SubtitleProfileFromJson(json);
  
  /// Gets or sets the format.
  @JsonKey(name: 'Format')
  final String? format;

  /// Gets or sets the delivery method.
  @JsonKey(name: 'Method')
  final SubtitleProfileMethod method;

  /// Gets or sets the DIDL mode.
  @JsonKey(name: 'DidlMode')
  final String? didlMode;

  /// Gets or sets the language.
  @JsonKey(name: 'Language')
  final String? language;

  /// Gets or sets the container.
  @JsonKey(name: 'Container')
  final String? container;

  Map<String, Object?> toJson() => _$SubtitleProfileToJson(this);
}
