// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'user_item_data_dto.g.dart';

/// Class UserItemDataDto.
@JsonSerializable()
class UserItemDataDto {
  const UserItemDataDto({
    required this.key,
    this.rating,
    this.playedPercentage,
    this.unplayedItemCount,
    this.playbackPositionTicks,
    this.playCount,
    this.isFavorite,
    this.likes,
    this.lastPlayedDate,
    this.played,
    this.itemId,
  });
  
  factory UserItemDataDto.fromJson(Map<String, Object?> json) => _$UserItemDataDtoFromJson(json);
  
  /// Gets or sets the rating.
  @JsonKey(name: 'Rating')
  final double? rating;

  /// Gets or sets the played percentage.
  @JsonKey(name: 'PlayedPercentage')
  final double? playedPercentage;

  /// Gets or sets the unplayed item count.
  @JsonKey(name: 'UnplayedItemCount')
  final int? unplayedItemCount;

  /// Gets or sets the playback position ticks.
  @JsonKey(name: 'PlaybackPositionTicks')
  final int? playbackPositionTicks;

  /// Gets or sets the play count.
  @JsonKey(name: 'PlayCount')
  final int? playCount;

  /// Gets or sets a value indicating whether this instance is favorite.
  @JsonKey(name: 'IsFavorite')
  final bool? isFavorite;

  /// Gets or sets a value indicating whether this MediaBrowser.Model.Dto.UserItemDataDto is likes.
  @JsonKey(name: 'Likes')
  final bool? likes;

  /// Gets or sets the last played date.
  @JsonKey(name: 'LastPlayedDate')
  final DateTime? lastPlayedDate;

  /// Gets or sets a value indicating whether this MediaBrowser.Model.Dto.UserItemDataDto is played.
  @JsonKey(name: 'Played')
  final bool? played;

  /// Gets or sets the key.
  @JsonKey(name: 'Key')
  final String key;

  /// Gets or sets the item identifier.
  @JsonKey(name: 'ItemId')
  final String? itemId;

  Map<String, Object?> toJson() => _$UserItemDataDtoToJson(this);
}
