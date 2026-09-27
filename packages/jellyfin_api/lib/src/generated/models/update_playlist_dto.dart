// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'playlist_user_permissions.dart';

part 'update_playlist_dto.g.dart';

/// Update existing playlist dto. Fields set to `null` will not be updated and keep their current values.
@JsonSerializable()
class UpdatePlaylistDto {
  const UpdatePlaylistDto({
    this.name,
    this.ids,
    this.users,
    this.isPublic,
  });
  
  factory UpdatePlaylistDto.fromJson(Map<String, Object?> json) => _$UpdatePlaylistDtoFromJson(json);
  
  /// Gets or sets the name of the new playlist.
  @JsonKey(name: 'Name')
  final String? name;

  /// Gets or sets item ids of the playlist.
  @JsonKey(name: 'Ids')
  final List<String>? ids;

  /// Gets or sets the playlist users.
  @JsonKey(name: 'Users')
  final List<PlaylistUserPermissions>? users;

  /// Gets or sets a value indicating whether the playlist is public.
  @JsonKey(name: 'IsPublic')
  final bool? isPublic;

  Map<String, Object?> toJson() => _$UpdatePlaylistDtoToJson(this);
}
