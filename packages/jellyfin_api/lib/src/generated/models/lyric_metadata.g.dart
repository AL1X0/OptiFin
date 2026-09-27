// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lyric_metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LyricMetadata _$LyricMetadataFromJson(Map<String, dynamic> json) =>
    LyricMetadata(
      artist: json['Artist'] as String?,
      album: json['Album'] as String?,
      title: json['Title'] as String?,
      author: json['Author'] as String?,
      length: (json['Length'] as num?)?.toInt(),
      by: json['By'] as String?,
      offset: (json['Offset'] as num?)?.toInt(),
      creator: json['Creator'] as String?,
      version: json['Version'] as String?,
      isSynced: json['IsSynced'] as bool?,
    );

Map<String, dynamic> _$LyricMetadataToJson(LyricMetadata instance) =>
    <String, dynamic>{
      'Artist': ?instance.artist,
      'Album': ?instance.album,
      'Title': ?instance.title,
      'Author': ?instance.author,
      'Length': ?instance.length,
      'By': ?instance.by,
      'Offset': ?instance.offset,
      'Creator': ?instance.creator,
      'Version': ?instance.version,
      'IsSynced': ?instance.isSynced,
    };
