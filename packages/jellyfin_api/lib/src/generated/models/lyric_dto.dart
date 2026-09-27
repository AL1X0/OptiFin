// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'lyric_line.dart';
import 'lyric_metadata.dart';

part 'lyric_dto.g.dart';

/// LyricResponse model.
@JsonSerializable()
class LyricDto {
  const LyricDto({
    required this.metadata,
    required this.lyrics,
  });
  
  factory LyricDto.fromJson(Map<String, Object?> json) => _$LyricDtoFromJson(json);
  
  /// Gets or sets Metadata for the lyrics.
  @JsonKey(name: 'Metadata')
  final LyricMetadata? metadata;

  /// Gets or sets a collection of individual lyric lines.
  @JsonKey(name: 'Lyrics')
  final List<LyricLine>? lyrics;

  Map<String, Object?> toJson() => _$LyricDtoToJson(this);
}
