// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'lyric_metadata.g.dart';

/// LyricMetadata model.
@JsonSerializable()
class LyricMetadata {
  const LyricMetadata({
    this.artist,
    this.album,
    this.title,
    this.author,
    this.length,
    this.by,
    this.offset,
    this.creator,
    this.version,
    this.isSynced,
  });
  
  factory LyricMetadata.fromJson(Map<String, Object?> json) => _$LyricMetadataFromJson(json);
  
  /// Gets or sets the song artist.
  @JsonKey(name: 'Artist')
  final String? artist;

  /// Gets or sets the album this song is on.
  @JsonKey(name: 'Album')
  final String? album;

  /// Gets or sets the title of the song.
  @JsonKey(name: 'Title')
  final String? title;

  /// Gets or sets the author of the lyric data.
  @JsonKey(name: 'Author')
  final String? author;

  /// Gets or sets the length of the song in ticks.
  @JsonKey(name: 'Length')
  final int? length;

  /// Gets or sets who the LRC file was created by.
  @JsonKey(name: 'By')
  final String? by;

  /// Gets or sets the lyric offset compared to audio in ticks.
  @JsonKey(name: 'Offset')
  final int? offset;

  /// Gets or sets the software used to create the LRC file.
  @JsonKey(name: 'Creator')
  final String? creator;

  /// Gets or sets the version of the creator used.
  @JsonKey(name: 'Version')
  final String? version;

  /// Gets or sets a value indicating whether this lyric is synced.
  @JsonKey(name: 'IsSynced')
  final bool? isSynced;

  Map<String, Object?> toJson() => _$LyricMetadataToJson(this);
}
