// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'base_item_person.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BaseItemPerson _$BaseItemPersonFromJson(Map<String, dynamic> json) =>
    BaseItemPerson(
      name: json['Name'] as String?,
      id: json['Id'] as String,
      role: json['Role'] as String?,
      type: json['Type'] == null
          ? null
          : BaseItemPersonType.fromJson(json['Type']),
      primaryImageTag: json['PrimaryImageTag'] as String?,
      imageBlurHashes: json['ImageBlurHashes'] == null
          ? null
          : ImageBlurHashes2.fromJson(
              json['ImageBlurHashes'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$BaseItemPersonToJson(BaseItemPerson instance) =>
    <String, dynamic>{
      'Name': instance.name,
      'Id': instance.id,
      'Role': instance.role,
      'Type': instance.type,
      'PrimaryImageTag': instance.primaryImageTag,
      'ImageBlurHashes': instance.imageBlurHashes,
    };
