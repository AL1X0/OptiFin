// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_update_info_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaUpdateInfoDto _$MediaUpdateInfoDtoFromJson(Map<String, dynamic> json) =>
    MediaUpdateInfoDto(
      updates: (json['Updates'] as List<dynamic>?)
          ?.map(
            (e) => MediaUpdateInfoPathDto.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );

Map<String, dynamic> _$MediaUpdateInfoDtoToJson(MediaUpdateInfoDto instance) =>
    <String, dynamic>{'Updates': ?instance.updates};
