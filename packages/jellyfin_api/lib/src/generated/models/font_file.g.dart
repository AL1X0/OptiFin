// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'font_file.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FontFile _$FontFileFromJson(Map<String, dynamic> json) => FontFile(
  name: json['Name'] as String?,
  size: (json['Size'] as num?)?.toInt(),
  dateCreated: json['DateCreated'] == null
      ? null
      : DateTime.parse(json['DateCreated'] as String),
  dateModified: json['DateModified'] == null
      ? null
      : DateTime.parse(json['DateModified'] as String),
);

Map<String, dynamic> _$FontFileToJson(FontFile instance) => <String, dynamic>{
  'Name': instance.name,
  'Size': instance.size,
  'DateCreated': instance.dateCreated?.toIso8601String(),
  'DateModified': instance.dateModified?.toIso8601String(),
};
