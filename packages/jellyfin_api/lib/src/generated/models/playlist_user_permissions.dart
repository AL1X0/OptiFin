// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'playlist_user_permissions.g.dart';

/// Class to hold data on user permissions for playlists.
@JsonSerializable()
class PlaylistUserPermissions {
  const PlaylistUserPermissions({
    this.userId,
    this.canEdit,
  });
  
  factory PlaylistUserPermissions.fromJson(Map<String, Object?> json) => _$PlaylistUserPermissionsFromJson(json);
  
  /// Gets or sets the user id.
  @JsonKey(name: 'UserId')
  final String? userId;

  /// Gets or sets a value indicating whether the user has edit permissions.
  @JsonKey(name: 'CanEdit')
  final bool? canEdit;

  Map<String, Object?> toJson() => _$PlaylistUserPermissionsToJson(this);
}
