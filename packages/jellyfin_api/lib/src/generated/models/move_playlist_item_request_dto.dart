// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'move_playlist_item_request_dto.g.dart';

/// Class MovePlaylistItemRequestDto.
@JsonSerializable()
class MovePlaylistItemRequestDto {
  const MovePlaylistItemRequestDto({
    this.playlistItemId,
    this.newIndex,
  });
  
  factory MovePlaylistItemRequestDto.fromJson(Map<String, Object?> json) => _$MovePlaylistItemRequestDtoFromJson(json);
  
  /// Gets or sets the playlist identifier of the item.
  @JsonKey(name: 'PlaylistItemId')
  final String? playlistItemId;

  /// Gets or sets the new position.
  @JsonKey(name: 'NewIndex')
  final int? newIndex;

  Map<String, Object?> toJson() => _$MovePlaylistItemRequestDtoToJson(this);
}
