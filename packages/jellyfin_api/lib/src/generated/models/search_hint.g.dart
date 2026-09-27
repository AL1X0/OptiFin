// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_hint.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SearchHint _$SearchHintFromJson(Map<String, dynamic> json) => SearchHint(
  itemId: json['ItemId'] as String?,
  id: json['Id'] as String,
  name: json['Name'] as String?,
  matchedTerm: json['MatchedTerm'] as String?,
  indexNumber: (json['IndexNumber'] as num?)?.toInt(),
  productionYear: (json['ProductionYear'] as num?)?.toInt(),
  parentIndexNumber: (json['ParentIndexNumber'] as num?)?.toInt(),
  primaryImageTag: json['PrimaryImageTag'] as String?,
  thumbImageTag: json['ThumbImageTag'] as String?,
  thumbImageItemId: json['ThumbImageItemId'] as String?,
  backdropImageTag: json['BackdropImageTag'] as String?,
  backdropImageItemId: json['BackdropImageItemId'] as String?,
  type: json['Type'] == null ? null : SearchHintType.fromJson(json['Type']),
  isFolder: json['IsFolder'] as bool?,
  runTimeTicks: (json['RunTimeTicks'] as num?)?.toInt(),
  mediaType: json['MediaType'] == null
      ? null
      : SearchHintMediaType.fromJson(json['MediaType']),
  startDate: json['StartDate'] == null
      ? null
      : DateTime.parse(json['StartDate'] as String),
  endDate: json['EndDate'] == null
      ? null
      : DateTime.parse(json['EndDate'] as String),
  series: json['Series'] as String?,
  status: json['Status'] as String?,
  album: json['Album'] as String?,
  albumId: json['AlbumId'] as String?,
  albumArtist: json['AlbumArtist'] as String?,
  artists: (json['Artists'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  songCount: (json['SongCount'] as num?)?.toInt(),
  episodeCount: (json['EpisodeCount'] as num?)?.toInt(),
  channelId: json['ChannelId'] as String?,
  channelName: json['ChannelName'] as String?,
  primaryImageAspectRatio: (json['PrimaryImageAspectRatio'] as num?)
      ?.toDouble(),
);

Map<String, dynamic> _$SearchHintToJson(SearchHint instance) =>
    <String, dynamic>{
      'ItemId': ?instance.itemId,
      'Id': instance.id,
      'Name': ?instance.name,
      'MatchedTerm': ?instance.matchedTerm,
      'IndexNumber': ?instance.indexNumber,
      'ProductionYear': ?instance.productionYear,
      'ParentIndexNumber': ?instance.parentIndexNumber,
      'PrimaryImageTag': ?instance.primaryImageTag,
      'ThumbImageTag': ?instance.thumbImageTag,
      'ThumbImageItemId': ?instance.thumbImageItemId,
      'BackdropImageTag': ?instance.backdropImageTag,
      'BackdropImageItemId': ?instance.backdropImageItemId,
      'Type': ?instance.type,
      'IsFolder': ?instance.isFolder,
      'RunTimeTicks': ?instance.runTimeTicks,
      'MediaType': ?instance.mediaType,
      'StartDate': ?instance.startDate?.toIso8601String(),
      'EndDate': ?instance.endDate?.toIso8601String(),
      'Series': ?instance.series,
      'Status': ?instance.status,
      'Album': ?instance.album,
      'AlbumId': ?instance.albumId,
      'AlbumArtist': ?instance.albumArtist,
      'Artists': ?instance.artists,
      'SongCount': ?instance.songCount,
      'EpisodeCount': ?instance.episodeCount,
      'ChannelId': ?instance.channelId,
      'ChannelName': ?instance.channelName,
      'PrimaryImageAspectRatio': ?instance.primaryImageAspectRatio,
    };
