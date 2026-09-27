// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'play_request_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlayRequestDto _$PlayRequestDtoFromJson(Map<String, dynamic> json) =>
    PlayRequestDto(
      playingQueue: (json['PlayingQueue'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      playingItemPosition: (json['PlayingItemPosition'] as num?)?.toInt(),
      startPositionTicks: (json['StartPositionTicks'] as num?)?.toInt(),
    );

Map<String, dynamic> _$PlayRequestDtoToJson(PlayRequestDto instance) =>
    <String, dynamic>{
      'PlayingQueue': instance.playingQueue,
      'PlayingItemPosition': instance.playingItemPosition,
      'StartPositionTicks': instance.startPositionTicks,
    };
