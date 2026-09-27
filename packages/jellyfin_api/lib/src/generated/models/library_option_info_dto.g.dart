// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_option_info_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LibraryOptionInfoDto _$LibraryOptionInfoDtoFromJson(
  Map<String, dynamic> json,
) => LibraryOptionInfoDto(
  name: json['Name'] as String?,
  defaultEnabled: json['DefaultEnabled'] as bool?,
);

Map<String, dynamic> _$LibraryOptionInfoDtoToJson(
  LibraryOptionInfoDto instance,
) => <String, dynamic>{
  'Name': instance.name,
  'DefaultEnabled': instance.defaultEnabled,
};
