// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item_counts.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ItemCounts _$ItemCountsFromJson(Map<String, dynamic> json) => ItemCounts(
  movieCount: (json['MovieCount'] as num?)?.toInt(),
  seriesCount: (json['SeriesCount'] as num?)?.toInt(),
  episodeCount: (json['EpisodeCount'] as num?)?.toInt(),
  artistCount: (json['ArtistCount'] as num?)?.toInt(),
  programCount: (json['ProgramCount'] as num?)?.toInt(),
  trailerCount: (json['TrailerCount'] as num?)?.toInt(),
  songCount: (json['SongCount'] as num?)?.toInt(),
  albumCount: (json['AlbumCount'] as num?)?.toInt(),
  musicVideoCount: (json['MusicVideoCount'] as num?)?.toInt(),
  boxSetCount: (json['BoxSetCount'] as num?)?.toInt(),
  bookCount: (json['BookCount'] as num?)?.toInt(),
  itemCount: (json['ItemCount'] as num?)?.toInt(),
);

Map<String, dynamic> _$ItemCountsToJson(ItemCounts instance) =>
    <String, dynamic>{
      'MovieCount': instance.movieCount,
      'SeriesCount': instance.seriesCount,
      'EpisodeCount': instance.episodeCount,
      'ArtistCount': instance.artistCount,
      'ProgramCount': instance.programCount,
      'TrailerCount': instance.trailerCount,
      'SongCount': instance.songCount,
      'AlbumCount': instance.albumCount,
      'MusicVideoCount': instance.musicVideoCount,
      'BoxSetCount': instance.boxSetCount,
      'BookCount': instance.bookCount,
      'ItemCount': instance.itemCount,
    };
