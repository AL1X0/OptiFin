// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'media_update_info_path_dto.g.dart';

/// The media update info path.
@JsonSerializable()
class MediaUpdateInfoPathDto {
  const MediaUpdateInfoPathDto({
    this.path,
    this.updateType,
  });
  
  factory MediaUpdateInfoPathDto.fromJson(Map<String, Object?> json) => _$MediaUpdateInfoPathDtoFromJson(json);
  
  /// Gets or sets media path.
  @JsonKey(name: 'Path')
  final String? path;

  /// Gets or sets media update type.
  /// Created, Modified, Deleted.
  @JsonKey(name: 'UpdateType')
  final String? updateType;

  Map<String, Object?> toJson() => _$MediaUpdateInfoPathDtoToJson(this);
}
