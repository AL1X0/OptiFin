// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_playlist_user_dto.g.dart';

/// Update existing playlist user dto. Fields set to `null` will not be updated and keep their current values.
@JsonSerializable()
class UpdatePlaylistUserDto {
  const UpdatePlaylistUserDto({
    this.canEdit,
  });
  
  factory UpdatePlaylistUserDto.fromJson(Map<String, Object?> json) => _$UpdatePlaylistUserDtoFromJson(json);
  
  /// Gets or sets a value indicating whether the user can edit the playlist.
  @JsonKey(name: 'CanEdit')
  final bool? canEdit;

  Map<String, Object?> toJson() => _$UpdatePlaylistUserDtoToJson(this);
}
