// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_option.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ImageOption _$ImageOptionFromJson(Map<String, dynamic> json) => ImageOption(
  type: json['Type'] == null ? null : ImageOptionType.fromJson(json['Type']),
  limit: (json['Limit'] as num?)?.toInt(),
  minWidth: (json['MinWidth'] as num?)?.toInt(),
);

Map<String, dynamic> _$ImageOptionToJson(ImageOption instance) =>
    <String, dynamic>{
      'Type': instance.type,
      'Limit': instance.limit,
      'MinWidth': instance.minWidth,
    };
