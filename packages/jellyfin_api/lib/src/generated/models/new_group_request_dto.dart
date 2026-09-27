// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'new_group_request_dto.g.dart';

/// Class NewGroupRequestDto.
@JsonSerializable()
class NewGroupRequestDto {
  const NewGroupRequestDto({
    this.groupName,
  });
  
  factory NewGroupRequestDto.fromJson(Map<String, Object?> json) => _$NewGroupRequestDtoFromJson(json);
  
  /// Gets or sets the group name.
  @JsonKey(name: 'GroupName')
  final String? groupName;

  Map<String, Object?> toJson() => _$NewGroupRequestDtoToJson(this);
}
