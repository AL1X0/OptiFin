// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_shuffle_mode_request_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SetShuffleModeRequestDto _$SetShuffleModeRequestDtoFromJson(
  Map<String, dynamic> json,
) => SetShuffleModeRequestDto(
  mode: json['Mode'] == null
      ? null
      : SetShuffleModeRequestDtoMode.fromJson(json['Mode']),
);

Map<String, dynamic> _$SetShuffleModeRequestDtoToJson(
  SetShuffleModeRequestDto instance,
) => <String, dynamic>{'Mode': ?instance.mode};
