// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_info_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GroupInfoDto _$GroupInfoDtoFromJson(Map<String, dynamic> json) => GroupInfoDto(
  groupId: json['GroupId'] as String?,
  groupName: json['GroupName'] as String?,
  state: json['State'] == null
      ? null
      : GroupInfoDtoState.fromJson(json['State']),
  participants: (json['Participants'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  lastUpdatedAt: json['LastUpdatedAt'] == null
      ? null
      : DateTime.parse(json['LastUpdatedAt'] as String),
);

Map<String, dynamic> _$GroupInfoDtoToJson(GroupInfoDto instance) =>
    <String, dynamic>{
      'GroupId': ?instance.groupId,
      'GroupName': ?instance.groupName,
      'State': ?instance.state,
      'Participants': ?instance.participants,
      'LastUpdatedAt': ?instance.lastUpdatedAt?.toIso8601String(),
    };
