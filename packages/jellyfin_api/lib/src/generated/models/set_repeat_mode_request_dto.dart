// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'set_repeat_mode_request_dto_mode.dart';

part 'set_repeat_mode_request_dto.g.dart';

/// Class SetRepeatModeRequestDto.
@JsonSerializable()
class SetRepeatModeRequestDto {
  const SetRepeatModeRequestDto({
    required this.mode,
  });
  
  factory SetRepeatModeRequestDto.fromJson(Map<String, Object?> json) => _$SetRepeatModeRequestDtoFromJson(json);
  
  /// Gets or sets the repeat mode.
  @JsonKey(name: 'Mode')
  final SetRepeatModeRequestDtoMode? mode;

  Map<String, Object?> toJson() => _$SetRepeatModeRequestDtoToJson(this);
}
