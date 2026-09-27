// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_user_item_data_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateUserItemDataDto _$UpdateUserItemDataDtoFromJson(
  Map<String, dynamic> json,
) => UpdateUserItemDataDto(
  rating: (json['Rating'] as num?)?.toDouble(),
  playedPercentage: (json['PlayedPercentage'] as num?)?.toDouble(),
  unplayedItemCount: (json['UnplayedItemCount'] as num?)?.toInt(),
  playbackPositionTicks: (json['PlaybackPositionTicks'] as num?)?.toInt(),
  playCount: (json['PlayCount'] as num?)?.toInt(),
  isFavorite: json['IsFavorite'] as bool?,
  likes: json['Likes'] as bool?,
  lastPlayedDate: json['LastPlayedDate'] == null
      ? null
      : DateTime.parse(json['LastPlayedDate'] as String),
  played: json['Played'] as bool?,
  key: json['Key'] as String?,
  itemId: json['ItemId'] as String?,
);

Map<String, dynamic> _$UpdateUserItemDataDtoToJson(
  UpdateUserItemDataDto instance,
) => <String, dynamic>{
  'Rating': ?instance.rating,
  'PlayedPercentage': ?instance.playedPercentage,
  'UnplayedItemCount': ?instance.unplayedItemCount,
  'PlaybackPositionTicks': ?instance.playbackPositionTicks,
  'PlayCount': ?instance.playCount,
  'IsFavorite': ?instance.isFavorite,
  'Likes': ?instance.likes,
  'LastPlayedDate': ?instance.lastPlayedDate?.toIso8601String(),
  'Played': ?instance.played,
  'Key': ?instance.key,
  'ItemId': ?instance.itemId,
};
