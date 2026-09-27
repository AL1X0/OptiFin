// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'theme_media_result.dart';

part 'all_theme_media_result.g.dart';

@JsonSerializable()
class AllThemeMediaResult {
  const AllThemeMediaResult({
    required this.themeVideosResult,
    required this.themeSongsResult,
    required this.soundtrackSongsResult,
  });
  
  factory AllThemeMediaResult.fromJson(Map<String, Object?> json) => _$AllThemeMediaResultFromJson(json);
  
  /// Class ThemeMediaResult.
  @JsonKey(name: 'ThemeVideosResult')
  final ThemeMediaResult? themeVideosResult;

  /// Class ThemeMediaResult.
  @JsonKey(name: 'ThemeSongsResult')
  final ThemeMediaResult? themeSongsResult;

  /// Class ThemeMediaResult.
  @JsonKey(name: 'SoundtrackSongsResult')
  final ThemeMediaResult? soundtrackSongsResult;

  Map<String, Object?> toJson() => _$AllThemeMediaResultToJson(this);
}
