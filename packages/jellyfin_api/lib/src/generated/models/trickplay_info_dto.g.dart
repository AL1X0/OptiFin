// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trickplay_info_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrickplayInfoDto _$TrickplayInfoDtoFromJson(Map<String, dynamic> json) =>
    TrickplayInfoDto(
      width: (json['Width'] as num?)?.toInt(),
      height: (json['Height'] as num?)?.toInt(),
      tileWidth: (json['TileWidth'] as num?)?.toInt(),
      tileHeight: (json['TileHeight'] as num?)?.toInt(),
      thumbnailCount: (json['ThumbnailCount'] as num?)?.toInt(),
      interval: (json['Interval'] as num?)?.toInt(),
      bandwidth: (json['Bandwidth'] as num?)?.toInt(),
    );

Map<String, dynamic> _$TrickplayInfoDtoToJson(TrickplayInfoDto instance) =>
    <String, dynamic>{
      'Width': instance.width,
      'Height': instance.height,
      'TileWidth': instance.tileWidth,
      'TileHeight': instance.tileHeight,
      'ThumbnailCount': instance.thumbnailCount,
      'Interval': instance.interval,
      'Bandwidth': instance.bandwidth,
    };
