// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'user_configuration_subtitle_mode.dart';

part 'user_configuration.g.dart';

/// Class UserConfiguration.
@JsonSerializable()
class UserConfiguration {
  const UserConfiguration({
    required this.audioLanguagePreference,
    required this.playDefaultAudioTrack,
    required this.subtitleLanguagePreference,
    required this.displayMissingEpisodes,
    required this.groupedFolders,
    required this.subtitleMode,
    required this.displayCollectionsView,
    required this.enableLocalPassword,
    required this.orderedViews,
    required this.latestItemsExcludes,
    required this.myMediaExcludes,
    required this.hidePlayedInLatest,
    required this.rememberAudioSelections,
    required this.rememberSubtitleSelections,
    required this.enableNextEpisodeAutoPlay,
    required this.castReceiverId,
  });
  
  factory UserConfiguration.fromJson(Map<String, Object?> json) => _$UserConfigurationFromJson(json);
  
  /// Gets or sets the audio language preference.
  @JsonKey(name: 'AudioLanguagePreference')
  final String? audioLanguagePreference;

  /// Gets or sets a value indicating whether [play default audio track].
  @JsonKey(name: 'PlayDefaultAudioTrack')
  final bool? playDefaultAudioTrack;

  /// Gets or sets the subtitle language preference.
  @JsonKey(name: 'SubtitleLanguagePreference')
  final String? subtitleLanguagePreference;
  @JsonKey(name: 'DisplayMissingEpisodes')
  final bool? displayMissingEpisodes;
  @JsonKey(name: 'GroupedFolders')
  final List<String>? groupedFolders;

  /// An enum representing a subtitle playback mode.
  @JsonKey(name: 'SubtitleMode')
  final UserConfigurationSubtitleMode? subtitleMode;
  @JsonKey(name: 'DisplayCollectionsView')
  final bool? displayCollectionsView;
  @JsonKey(name: 'EnableLocalPassword')
  final bool? enableLocalPassword;
  @JsonKey(name: 'OrderedViews')
  final List<String>? orderedViews;
  @JsonKey(name: 'LatestItemsExcludes')
  final List<String>? latestItemsExcludes;
  @JsonKey(name: 'MyMediaExcludes')
  final List<String>? myMediaExcludes;
  @JsonKey(name: 'HidePlayedInLatest')
  final bool? hidePlayedInLatest;
  @JsonKey(name: 'RememberAudioSelections')
  final bool? rememberAudioSelections;
  @JsonKey(name: 'RememberSubtitleSelections')
  final bool? rememberSubtitleSelections;
  @JsonKey(name: 'EnableNextEpisodeAutoPlay')
  final bool? enableNextEpisodeAutoPlay;

  /// Gets or sets the id of the selected cast receiver.
  @JsonKey(name: 'CastReceiverId')
  final String? castReceiverId;

  Map<String, Object?> toJson() => _$UserConfigurationToJson(this);
}
