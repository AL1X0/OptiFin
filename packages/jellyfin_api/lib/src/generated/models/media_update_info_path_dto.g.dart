// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_update_info_path_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaUpdateInfoPathDto _$MediaUpdateInfoPathDtoFromJson(
  Map<String, dynamic> json,
) => MediaUpdateInfoPathDto(
  path: json['Path'] as String?,
  updateType: json['UpdateType'] as String?,
);

Map<String, dynamic> _$MediaUpdateInfoPathDtoToJson(
  MediaUpdateInfoPathDto instance,
) => <String, dynamic>{
  'Path': ?instance.path,
  'UpdateType': ?instance.updateType,
};
