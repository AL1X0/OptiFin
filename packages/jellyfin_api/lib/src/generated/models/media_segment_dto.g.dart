// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_segment_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaSegmentDto _$MediaSegmentDtoFromJson(Map<String, dynamic> json) =>
    MediaSegmentDto(
      id: json['Id'] as String,
      itemId: json['ItemId'] as String,
      type: MediaSegmentDtoType.fromJson(json['Type']),
      startTicks: (json['StartTicks'] as num).toInt(),
      endTicks: (json['EndTicks'] as num).toInt(),
    );

Map<String, dynamic> _$MediaSegmentDtoToJson(MediaSegmentDto instance) =>
    <String, dynamic>{
      'Id': instance.id,
      'ItemId': instance.itemId,
      'Type': instance.type,
      'StartTicks': instance.startTicks,
      'EndTicks': instance.endTicks,
    };
