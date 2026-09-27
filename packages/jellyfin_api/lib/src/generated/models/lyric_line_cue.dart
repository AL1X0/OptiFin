// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'lyric_line_cue.g.dart';

/// LyricLineCue model, holds information about the timing of words within a LyricLine.
@JsonSerializable()
class LyricLineCue {
  const LyricLineCue({
    this.position,
    this.endPosition,
    this.start,
    this.end,
  });
  
  factory LyricLineCue.fromJson(Map<String, Object?> json) => _$LyricLineCueFromJson(json);
  
  /// Gets the start character index of the cue.
  @JsonKey(name: 'Position')
  final int? position;

  /// Gets the end character index of the cue.
  @JsonKey(name: 'EndPosition')
  final int? endPosition;

  /// Gets the timestamp the lyric is synced to in ticks.
  @JsonKey(name: 'Start')
  final int? start;

  /// Gets the end timestamp the lyric is synced to in ticks.
  @JsonKey(name: 'End')
  final int? end;

  Map<String, Object?> toJson() => _$LyricLineCueToJson(this);
}
