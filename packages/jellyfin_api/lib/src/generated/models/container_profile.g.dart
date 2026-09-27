// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'container_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ContainerProfile _$ContainerProfileFromJson(Map<String, dynamic> json) =>
    ContainerProfile(
      type: json['Type'] == null
          ? null
          : ContainerProfileType.fromJson(json['Type']),
      conditions: (json['Conditions'] as List<dynamic>?)
          ?.map((e) => ProfileCondition.fromJson(e as Map<String, dynamic>))
          .toList(),
      container: json['Container'] as String?,
      subContainer: json['SubContainer'] as String?,
    );

Map<String, dynamic> _$ContainerProfileToJson(ContainerProfile instance) =>
    <String, dynamic>{
      'Type': ?instance.type,
      'Conditions': ?instance.conditions,
      'Container': ?instance.container,
      'SubContainer': ?instance.subContainer,
    };
