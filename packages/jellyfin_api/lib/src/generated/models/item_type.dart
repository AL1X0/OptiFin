// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

/// The base item kind.
@JsonEnum()
enum ItemType {
  @JsonValue('AggregateFolder')
  aggregateFolder('AggregateFolder'),
  @JsonValue('Audio')
  audio('Audio'),
  @JsonValue('AudioBook')
  audioBook('AudioBook'),
  @JsonValue('BasePluginFolder')
  basePluginFolder('BasePluginFolder'),
  @JsonValue('Book')
  book('Book'),
  @JsonValue('BoxSet')
  boxSet('BoxSet'),
  @JsonValue('Channel')
  channel('Channel'),
  @JsonValue('ChannelFolderItem')
  channelFolderItem('ChannelFolderItem'),
  @JsonValue('CollectionFolder')
  collectionFolder('CollectionFolder'),
  @JsonValue('Episode')
  episode('Episode'),
  @JsonValue('Folder')
  folder('Folder'),
  @JsonValue('Genre')
  genre('Genre'),
  @JsonValue('ManualPlaylistsFolder')
  manualPlaylistsFolder('ManualPlaylistsFolder'),
  @JsonValue('Movie')
  movie('Movie'),
  @JsonValue('LiveTvChannel')
  liveTvChannel('LiveTvChannel'),
  @JsonValue('LiveTvProgram')
  liveTvProgram('LiveTvProgram'),
  @JsonValue('MusicAlbum')
  musicAlbum('MusicAlbum'),
  @JsonValue('MusicArtist')
  musicArtist('MusicArtist'),
  @JsonValue('MusicGenre')
  musicGenre('MusicGenre'),
  @JsonValue('MusicVideo')
  musicVideo('MusicVideo'),
  @JsonValue('Person')
  person('Person'),
  @JsonValue('Photo')
  photo('Photo'),
  @JsonValue('PhotoAlbum')
  photoAlbum('PhotoAlbum'),
  @JsonValue('Playlist')
  playlist('Playlist'),
  @JsonValue('PlaylistsFolder')
  playlistsFolder('PlaylistsFolder'),
  @JsonValue('Program')
  program('Program'),
  @JsonValue('Recording')
  recording('Recording'),
  @JsonValue('Season')
  season('Season'),
  @JsonValue('Series')
  series('Series'),
  @JsonValue('Studio')
  studio('Studio'),
  @JsonValue('Trailer')
  trailer('Trailer'),
  @JsonValue('TvChannel')
  tvChannel('TvChannel'),
  @JsonValue('TvProgram')
  tvProgram('TvProgram'),
  @JsonValue('UserRootFolder')
  userRootFolder('UserRootFolder'),
  @JsonValue('UserView')
  userView('UserView'),
  @JsonValue('Video')
  video('Video'),
  @JsonValue('Year')
  year('Year'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const ItemType(this.json);

  factory ItemType.fromJson(dynamic json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final dynamic json;
  dynamic toJson() {
    final value = json;
    if (value == null) {
      throw StateError('Cannot convert enum value with null JSON representation to dynamic. '
          'This usually happens for \$unknown or @JsonValue(null) entries.');
    }
    return value as dynamic;
  }

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<ItemType> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
