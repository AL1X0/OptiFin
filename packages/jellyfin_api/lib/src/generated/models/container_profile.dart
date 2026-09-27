// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'container_profile_type.dart';
import 'profile_condition.dart';

part 'container_profile.g.dart';

/// Defines the MediaBrowser.Model.Dlna.ContainerProfile.
@JsonSerializable()
class ContainerProfile {
  const ContainerProfile({
    required this.type,
    required this.conditions,
    required this.container,
    required this.subContainer,
  });
  
  factory ContainerProfile.fromJson(Map<String, Object?> json) => _$ContainerProfileFromJson(json);
  
  /// Gets or sets the MediaBrowser.Model.Dlna.DlnaProfileType which this container must meet.
  @JsonKey(name: 'Type')
  final ContainerProfileType? type;

  /// Gets or sets the list of MediaBrowser.Model.Dlna.ProfileCondition which this container will be applied to.
  @JsonKey(name: 'Conditions')
  final List<ProfileCondition>? conditions;

  /// Gets or sets the container(s) which this container must meet.
  @JsonKey(name: 'Container')
  final String? container;

  /// Gets or sets the sub container(s) which this container must meet.
  @JsonKey(name: 'SubContainer')
  final String? subContainer;

  Map<String, Object?> toJson() => _$ContainerProfileToJson(this);
}
