// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'lyric_line_cue.dart';

part 'lyric_line.g.dart';

/// Lyric model.
@JsonSerializable()
class LyricLine {
  const LyricLine({
    this.text,
    this.start,
    this.cues,
  });
  
  factory LyricLine.fromJson(Map<String, Object?> json) => _$LyricLineFromJson(json);
  
  /// Gets the text of this lyric line.
  @JsonKey(name: 'Text')
  final String? text;

  /// Gets the start time in ticks.
  @JsonKey(name: 'Start')
  final int? start;

  /// Gets the time-aligned cues for the song's lyrics.
  @JsonKey(name: 'Cues')
  final List<LyricLineCue>? cues;

  Map<String, Object?> toJson() => _$LyricLineToJson(this);
}
