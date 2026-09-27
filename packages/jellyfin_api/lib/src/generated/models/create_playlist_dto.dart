// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'create_playlist_dto_media_type.dart';
import 'playlist_user_permissions.dart';

part 'create_playlist_dto.g.dart';

/// Create new playlist dto.
@JsonSerializable()
class CreatePlaylistDto {
  const CreatePlaylistDto({
    required this.name,
    this.ids,
    this.userId,
    this.mediaType,
    this.users,
    this.isPublic,
  });
  
  factory CreatePlaylistDto.fromJson(Map<String, Object?> json) => _$CreatePlaylistDtoFromJson(json);
  
  /// Gets or sets the name of the new playlist.
  @JsonKey(name: 'Name')
  final String name;

  /// Gets or sets item ids to add to the playlist.
  @JsonKey(name: 'Ids')
  final List<String>? ids;

  /// Gets or sets the user id.
  @JsonKey(name: 'UserId')
  final String? userId;

  /// Gets or sets the media type.
  @JsonKey(name: 'MediaType')
  final CreatePlaylistDtoMediaType? mediaType;

  /// Gets or sets the playlist users.
  @JsonKey(name: 'Users')
  final List<PlaylistUserPermissions>? users;

  /// Gets or sets a value indicating whether the playlist is public.
  @JsonKey(name: 'IsPublic')
  final bool? isPublic;

  Map<String, Object?> toJson() => _$CreatePlaylistDtoToJson(this);
}
