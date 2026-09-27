// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'playlist_user_permissions.dart';

part 'playlist_dto.g.dart';

/// DTO for playlists.
@JsonSerializable()
class PlaylistDto {
  const PlaylistDto({
    this.openAccess,
    this.shares,
    this.itemIds,
  });
  
  factory PlaylistDto.fromJson(Map<String, Object?> json) => _$PlaylistDtoFromJson(json);
  
  /// Gets or sets a value indicating whether the playlist is publicly readable.
  @JsonKey(name: 'OpenAccess')
  final bool? openAccess;

  /// Gets or sets the share permissions.
  @JsonKey(name: 'Shares')
  final List<PlaylistUserPermissions>? shares;

  /// Gets or sets the item ids.
  @JsonKey(name: 'ItemIds')
  final List<String>? itemIds;

  Map<String, Object?> toJson() => _$PlaylistDtoToJson(this);
}
