// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'all_theme_media_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AllThemeMediaResult _$AllThemeMediaResultFromJson(Map<String, dynamic> json) =>
    AllThemeMediaResult(
      themeVideosResult: json['ThemeVideosResult'] == null
          ? null
          : ThemeMediaResult.fromJson(
              json['ThemeVideosResult'] as Map<String, dynamic>,
            ),
      themeSongsResult: json['ThemeSongsResult'] == null
          ? null
          : ThemeMediaResult.fromJson(
              json['ThemeSongsResult'] as Map<String, dynamic>,
            ),
      soundtrackSongsResult: json['SoundtrackSongsResult'] == null
          ? null
          : ThemeMediaResult.fromJson(
              json['SoundtrackSongsResult'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$AllThemeMediaResultToJson(
  AllThemeMediaResult instance,
) => <String, dynamic>{
  'ThemeVideosResult': ?instance.themeVideosResult,
  'ThemeSongsResult': ?instance.themeSongsResult,
  'SoundtrackSongsResult': ?instance.soundtrackSongsResult,
};
