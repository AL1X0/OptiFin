// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue_request_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QueueRequestDto _$QueueRequestDtoFromJson(Map<String, dynamic> json) =>
    QueueRequestDto(
      itemIds: (json['ItemIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      mode: QueueRequestDtoMode.fromJson(json['Mode']),
    );

Map<String, dynamic> _$QueueRequestDtoToJson(QueueRequestDto instance) =>
    <String, dynamic>{'ItemIds': instance.itemIds, 'Mode': instance.mode};
