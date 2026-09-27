// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'move_playlist_item_request_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MovePlaylistItemRequestDto _$MovePlaylistItemRequestDtoFromJson(
  Map<String, dynamic> json,
) => MovePlaylistItemRequestDto(
  playlistItemId: json['PlaylistItemId'] as String?,
  newIndex: (json['NewIndex'] as num?)?.toInt(),
);

Map<String, dynamic> _$MovePlaylistItemRequestDtoToJson(
  MovePlaylistItemRequestDto instance,
) => <String, dynamic>{
  'PlaylistItemId': ?instance.playlistItemId,
  'NewIndex': ?instance.newIndex,
};
