// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codec_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CodecProfile _$CodecProfileFromJson(Map<String, dynamic> json) => CodecProfile(
  type: CodecProfileType.fromJson(json['Type']),
  conditions: (json['Conditions'] as List<dynamic>)
      .map((e) => ProfileCondition.fromJson(e as Map<String, dynamic>))
      .toList(),
  applyConditions: (json['ApplyConditions'] as List<dynamic>)
      .map((e) => ProfileCondition.fromJson(e as Map<String, dynamic>))
      .toList(),
  codec: json['Codec'] as String?,
  container: json['Container'] as String?,
  subContainer: json['SubContainer'] as String?,
);

Map<String, dynamic> _$CodecProfileToJson(CodecProfile instance) =>
    <String, dynamic>{
      'Type': instance.type,
      'Conditions': instance.conditions,
      'ApplyConditions': instance.applyConditions,
      'Codec': instance.codec,
      'Container': instance.container,
      'SubContainer': instance.subContainer,
    };
