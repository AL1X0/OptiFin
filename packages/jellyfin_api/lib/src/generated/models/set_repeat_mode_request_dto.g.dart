// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_repeat_mode_request_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SetRepeatModeRequestDto _$SetRepeatModeRequestDtoFromJson(
  Map<String, dynamic> json,
) => SetRepeatModeRequestDto(
  mode: json['Mode'] == null
      ? null
      : SetRepeatModeRequestDtoMode.fromJson(json['Mode']),
);

Map<String, dynamic> _$SetRepeatModeRequestDtoToJson(
  SetRepeatModeRequestDto instance,
) => <String, dynamic>{'Mode': instance.mode};
