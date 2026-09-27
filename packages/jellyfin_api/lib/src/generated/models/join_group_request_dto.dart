// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'join_group_request_dto.g.dart';

/// Class JoinGroupRequestDto.
@JsonSerializable()
class JoinGroupRequestDto {
  const JoinGroupRequestDto({
    this.groupId,
  });
  
  factory JoinGroupRequestDto.fromJson(Map<String, Object?> json) => _$JoinGroupRequestDtoFromJson(json);
  
  /// Gets or sets the group identifier.
  @JsonKey(name: 'GroupId')
  final String? groupId;

  Map<String, Object?> toJson() => _$JoinGroupRequestDtoToJson(this);
}
