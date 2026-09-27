// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'item_counts.g.dart';

/// Class LibrarySummary.
@JsonSerializable()
class ItemCounts {
  const ItemCounts({
    this.movieCount,
    this.seriesCount,
    this.episodeCount,
    this.artistCount,
    this.programCount,
    this.trailerCount,
    this.songCount,
    this.albumCount,
    this.musicVideoCount,
    this.boxSetCount,
    this.bookCount,
    this.itemCount,
  });
  
  factory ItemCounts.fromJson(Map<String, Object?> json) => _$ItemCountsFromJson(json);
  
  /// Gets or sets the movie count.
  @JsonKey(name: 'MovieCount')
  final int? movieCount;

  /// Gets or sets the series count.
  @JsonKey(name: 'SeriesCount')
  final int? seriesCount;

  /// Gets or sets the episode count.
  @JsonKey(name: 'EpisodeCount')
  final int? episodeCount;

  /// Gets or sets the artist count.
  @JsonKey(name: 'ArtistCount')
  final int? artistCount;

  /// Gets or sets the program count.
  @JsonKey(name: 'ProgramCount')
  final int? programCount;

  /// Gets or sets the trailer count.
  @JsonKey(name: 'TrailerCount')
  final int? trailerCount;

  /// Gets or sets the song count.
  @JsonKey(name: 'SongCount')
  final int? songCount;

  /// Gets or sets the album count.
  @JsonKey(name: 'AlbumCount')
  final int? albumCount;

  /// Gets or sets the music video count.
  @JsonKey(name: 'MusicVideoCount')
  final int? musicVideoCount;

  /// Gets or sets the box set count.
  @JsonKey(name: 'BoxSetCount')
  final int? boxSetCount;

  /// Gets or sets the book count.
  @JsonKey(name: 'BookCount')
  final int? bookCount;

  /// Gets or sets the item count.
  @JsonKey(name: 'ItemCount')
  final int? itemCount;

  Map<String, Object?> toJson() => _$ItemCountsToJson(this);
}
