// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'remove_from_playlist_request_dto.g.dart';

/// Class RemoveFromPlaylistRequestDto.
@JsonSerializable()
class RemoveFromPlaylistRequestDto {
  const RemoveFromPlaylistRequestDto({
    this.playlistItemIds,
    this.clearPlaylist,
    this.clearPlayingItem,
  });
  
  factory RemoveFromPlaylistRequestDto.fromJson(Map<String, Object?> json) => _$RemoveFromPlaylistRequestDtoFromJson(json);
  
  /// Gets or sets the playlist identifiers of the items. Ignored when clearing the playlist.
  @JsonKey(name: 'PlaylistItemIds')
  final List<String>? playlistItemIds;

  /// Gets or sets a value indicating whether the entire playlist should be cleared.
  @JsonKey(name: 'ClearPlaylist')
  final bool? clearPlaylist;

  /// Gets or sets a value indicating whether the playing item should be removed as well. Used only when clearing the playlist.
  @JsonKey(name: 'ClearPlayingItem')
  final bool? clearPlayingItem;

  Map<String, Object?> toJson() => _$RemoveFromPlaylistRequestDtoToJson(this);
}
