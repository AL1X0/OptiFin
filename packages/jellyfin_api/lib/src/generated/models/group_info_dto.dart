// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'group_info_dto_state.dart';

part 'group_info_dto.g.dart';

/// Class GroupInfoDto.
@JsonSerializable()
class GroupInfoDto {
  const GroupInfoDto({
    required this.groupId,
    required this.groupName,
    required this.state,
    required this.participants,
    required this.lastUpdatedAt,
  });
  
  factory GroupInfoDto.fromJson(Map<String, Object?> json) => _$GroupInfoDtoFromJson(json);
  
  /// Gets the group identifier.
  @JsonKey(name: 'GroupId')
  final String groupId;

  /// Gets the group name.
  @JsonKey(name: 'GroupName')
  final String groupName;

  /// Gets the group state.
  @JsonKey(name: 'State')
  final GroupInfoDtoState state;

  /// Gets the participants.
  @JsonKey(name: 'Participants')
  final List<String> participants;

  /// Gets the date when this DTO has been created.
  @JsonKey(name: 'LastUpdatedAt')
  final DateTime lastUpdatedAt;

  Map<String, Object?> toJson() => _$GroupInfoDtoToJson(this);
}
