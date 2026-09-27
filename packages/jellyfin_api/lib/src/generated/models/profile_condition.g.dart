// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_condition.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileCondition _$ProfileConditionFromJson(Map<String, dynamic> json) =>
    ProfileCondition(
      condition: ProfileConditionCondition.fromJson(json['Condition']),
      property: ProfileConditionProperty.fromJson(json['Property']),
      value: json['Value'] as String?,
      isRequired: json['IsRequired'] as bool,
    );

Map<String, dynamic> _$ProfileConditionToJson(ProfileCondition instance) =>
    <String, dynamic>{
      'Condition': instance.condition,
      'Property': instance.property,
      'Value': instance.value,
      'IsRequired': instance.isRequired,
    };
