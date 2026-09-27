// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'library_option_info_dto.g.dart';

/// Library option info dto.
@JsonSerializable()
class LibraryOptionInfoDto {
  const LibraryOptionInfoDto({
    this.name,
    this.defaultEnabled,
  });
  
  factory LibraryOptionInfoDto.fromJson(Map<String, Object?> json) => _$LibraryOptionInfoDtoFromJson(json);
  
  /// Gets or sets name.
  @JsonKey(name: 'Name')
  final String? name;

  /// Gets or sets a value indicating whether default enabled.
  @JsonKey(name: 'DefaultEnabled')
  final bool? defaultEnabled;

  Map<String, Object?> toJson() => _$LibraryOptionInfoDtoToJson(this);
}
