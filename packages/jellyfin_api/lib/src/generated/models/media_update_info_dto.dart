// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'media_update_info_path_dto.dart';

part 'media_update_info_dto.g.dart';

/// Media Update Info Dto.
@JsonSerializable()
class MediaUpdateInfoDto {
  const MediaUpdateInfoDto({
    this.updates,
  });
  
  factory MediaUpdateInfoDto.fromJson(Map<String, Object?> json) => _$MediaUpdateInfoDtoFromJson(json);
  
  /// Gets or sets the list of updates.
  @JsonKey(name: 'Updates')
  final List<MediaUpdateInfoPathDto>? updates;

  Map<String, Object?> toJson() => _$MediaUpdateInfoDtoToJson(this);
}
