// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'special_view_option_dto.g.dart';

/// Special view option dto.
@JsonSerializable()
class SpecialViewOptionDto {
  const SpecialViewOptionDto({
    this.name,
    this.id,
  });
  
  factory SpecialViewOptionDto.fromJson(Map<String, Object?> json) => _$SpecialViewOptionDtoFromJson(json);
  
  /// Gets or sets view option name.
  @JsonKey(name: 'Name')
  final String? name;

  /// Gets or sets view option id.
  @JsonKey(name: 'Id')
  final String? id;

  Map<String, Object?> toJson() => _$SpecialViewOptionDtoToJson(this);
}
