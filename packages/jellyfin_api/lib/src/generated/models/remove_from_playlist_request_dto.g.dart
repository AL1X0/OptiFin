// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remove_from_playlist_request_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RemoveFromPlaylistRequestDto _$RemoveFromPlaylistRequestDtoFromJson(
  Map<String, dynamic> json,
) => RemoveFromPlaylistRequestDto(
  playlistItemIds: (json['PlaylistItemIds'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  clearPlaylist: json['ClearPlaylist'] as bool?,
  clearPlayingItem: json['ClearPlayingItem'] as bool?,
);

Map<String, dynamic> _$RemoveFromPlaylistRequestDtoToJson(
  RemoveFromPlaylistRequestDto instance,
) => <String, dynamic>{
  'PlaylistItemIds': ?instance.playlistItemIds,
  'ClearPlaylist': ?instance.clearPlaylist,
  'ClearPlayingItem': ?instance.clearPlayingItem,
};
