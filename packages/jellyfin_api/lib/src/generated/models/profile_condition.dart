// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'profile_condition_condition.dart';
import 'profile_condition_property.dart';

part 'profile_condition.g.dart';

@JsonSerializable()
class ProfileCondition {
  const ProfileCondition({
    required this.condition,
    required this.property,
    required this.value,
    required this.isRequired,
  });
  
  factory ProfileCondition.fromJson(Map<String, Object?> json) => _$ProfileConditionFromJson(json);
  
  @JsonKey(name: 'Condition')
  final ProfileConditionCondition condition;
  @JsonKey(name: 'Property')
  final ProfileConditionProperty property;
  @JsonKey(name: 'Value')
  final String? value;
  @JsonKey(name: 'IsRequired')
  final bool isRequired;

  Map<String, Object?> toJson() => _$ProfileConditionToJson(this);
}
