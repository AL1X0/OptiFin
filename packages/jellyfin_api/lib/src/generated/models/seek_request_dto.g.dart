// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seek_request_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SeekRequestDto _$SeekRequestDtoFromJson(Map<String, dynamic> json) =>
    SeekRequestDto(positionTicks: (json['PositionTicks'] as num?)?.toInt());

Map<String, dynamic> _$SeekRequestDtoToJson(SeekRequestDto instance) =>
    <String, dynamic>{'PositionTicks': instance.positionTicks};
