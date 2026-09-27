// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'set_playlist_item_request_dto.g.dart';

/// Class SetPlaylistItemRequestDto.
@JsonSerializable()
class SetPlaylistItemRequestDto {
  const SetPlaylistItemRequestDto({
    this.playlistItemId,
  });
  
  factory SetPlaylistItemRequestDto.fromJson(Map<String, Object?> json) => _$SetPlaylistItemRequestDtoFromJson(json);
  
  /// Gets or sets the playlist identifier of the playing item.
  @JsonKey(name: 'PlaylistItemId')
  final String? playlistItemId;

  Map<String, Object?> toJson() => _$SetPlaylistItemRequestDtoToJson(this);
}
