// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'search_hint_media_type.dart';
import 'search_hint_type.dart';

part 'search_hint.g.dart';

/// Class SearchHintResult.
@JsonSerializable()
class SearchHint {
  const SearchHint({
    required this.itemId,
    required this.id,
    required this.name,
    required this.matchedTerm,
    required this.indexNumber,
    required this.productionYear,
    required this.parentIndexNumber,
    required this.primaryImageTag,
    required this.thumbImageTag,
    required this.thumbImageItemId,
    required this.backdropImageTag,
    required this.backdropImageItemId,
    required this.type,
    required this.isFolder,
    required this.runTimeTicks,
    required this.mediaType,
    required this.startDate,
    required this.endDate,
    required this.series,
    required this.status,
    required this.album,
    required this.albumId,
    required this.albumArtist,
    required this.artists,
    required this.songCount,
    required this.episodeCount,
    required this.channelId,
    required this.channelName,
    required this.primaryImageAspectRatio,
  });
  
  factory SearchHint.fromJson(Map<String, Object?> json) => _$SearchHintFromJson(json);
  
  /// Gets or sets the item id.
  @JsonKey(name: 'ItemId')
  final String itemId;

  /// Gets or sets the item id.
  @JsonKey(name: 'Id')
  final String id;

  /// Gets or sets the name.
  @JsonKey(name: 'Name')
  final String name;

  /// Gets or sets the matched term.
  @JsonKey(name: 'MatchedTerm')
  final String? matchedTerm;

  /// Gets or sets the index number.
  @JsonKey(name: 'IndexNumber')
  final int? indexNumber;

  /// Gets or sets the production year.
  @JsonKey(name: 'ProductionYear')
  final int? productionYear;

  /// Gets or sets the parent index number.
  @JsonKey(name: 'ParentIndexNumber')
  final int? parentIndexNumber;

  /// Gets or sets the image tag.
  @JsonKey(name: 'PrimaryImageTag')
  final String? primaryImageTag;

  /// Gets or sets the thumb image tag.
  @JsonKey(name: 'ThumbImageTag')
  final String? thumbImageTag;

  /// Gets or sets the thumb image item identifier.
  @JsonKey(name: 'ThumbImageItemId')
  final String? thumbImageItemId;

  /// Gets or sets the backdrop image tag.
  @JsonKey(name: 'BackdropImageTag')
  final String? backdropImageTag;

  /// Gets or sets the backdrop image item identifier.
  @JsonKey(name: 'BackdropImageItemId')
  final String? backdropImageItemId;

  /// The base item kind.
  @JsonKey(name: 'Type')
  final SearchHintType type;

  /// Gets or sets a value indicating whether this instance is folder.
  @JsonKey(name: 'IsFolder')
  final bool? isFolder;

  /// Gets or sets the run time ticks.
  @JsonKey(name: 'RunTimeTicks')
  final int? runTimeTicks;

  /// Media types.
  @JsonKey(name: 'MediaType')
  final SearchHintMediaType mediaType;

  /// Gets or sets the start date.
  @JsonKey(name: 'StartDate')
  final DateTime? startDate;

  /// Gets or sets the end date.
  @JsonKey(name: 'EndDate')
  final DateTime? endDate;

  /// Gets or sets the series.
  @JsonKey(name: 'Series')
  final String? series;

  /// Gets or sets the status.
  @JsonKey(name: 'Status')
  final String? status;

  /// Gets or sets the album.
  @JsonKey(name: 'Album')
  final String? album;

  /// Gets or sets the album id.
  @JsonKey(name: 'AlbumId')
  final String? albumId;

  /// Gets or sets the album artist.
  @JsonKey(name: 'AlbumArtist')
  final String? albumArtist;

  /// Gets or sets the artists.
  @JsonKey(name: 'Artists')
  final List<String> artists;

  /// Gets or sets the song count.
  @JsonKey(name: 'SongCount')
  final int? songCount;

  /// Gets or sets the episode count.
  @JsonKey(name: 'EpisodeCount')
  final int? episodeCount;

  /// Gets or sets the channel identifier.
  @JsonKey(name: 'ChannelId')
  final String? channelId;

  /// Gets or sets the name of the channel.
  @JsonKey(name: 'ChannelName')
  final String? channelName;

  /// Gets or sets the primary image aspect ratio.
  @JsonKey(name: 'PrimaryImageAspectRatio')
  final double? primaryImageAspectRatio;

  Map<String, Object?> toJson() => _$SearchHintToJson(this);
}
