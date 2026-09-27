// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'codec_profile_type.dart';
import 'profile_condition.dart';

part 'codec_profile.g.dart';

/// Defines the MediaBrowser.Model.Dlna.CodecProfile.
@JsonSerializable()
class CodecProfile {
  const CodecProfile({
    required this.type,
    required this.conditions,
    required this.applyConditions,
    required this.codec,
    required this.container,
    required this.subContainer,
  });
  
  factory CodecProfile.fromJson(Map<String, Object?> json) => _$CodecProfileFromJson(json);
  
  /// Gets or sets the MediaBrowser.Model.Dlna.CodecType which this container must meet.
  @JsonKey(name: 'Type')
  final CodecProfileType? type;

  /// Gets or sets the list of MediaBrowser.Model.Dlna.ProfileCondition which this profile must meet.
  @JsonKey(name: 'Conditions')
  final List<ProfileCondition>? conditions;

  /// Gets or sets the list of MediaBrowser.Model.Dlna.ProfileCondition to apply if this profile is met.
  @JsonKey(name: 'ApplyConditions')
  final List<ProfileCondition>? applyConditions;

  /// Gets or sets the codec(s) that this profile applies to.
  @JsonKey(name: 'Codec')
  final String? codec;

  /// Gets or sets the container(s) which this profile will be applied to.
  @JsonKey(name: 'Container')
  final String? container;

  /// Gets or sets the sub-container(s) which this profile will be applied to.
  @JsonKey(name: 'SubContainer')
  final String? subContainer;

  Map<String, Object?> toJson() => _$CodecProfileToJson(this);
}
