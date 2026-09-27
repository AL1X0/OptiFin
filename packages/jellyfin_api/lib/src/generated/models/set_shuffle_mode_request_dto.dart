// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'set_shuffle_mode_request_dto_mode.dart';

part 'set_shuffle_mode_request_dto.g.dart';

/// Class SetShuffleModeRequestDto.
@JsonSerializable()
class SetShuffleModeRequestDto {
  const SetShuffleModeRequestDto({
    required this.mode,
  });
  
  factory SetShuffleModeRequestDto.fromJson(Map<String, Object?> json) => _$SetShuffleModeRequestDtoFromJson(json);
  
  /// Gets or sets the shuffle mode.
  @JsonKey(name: 'Mode')
  final SetShuffleModeRequestDtoMode mode;

  Map<String, Object?> toJson() => _$SetShuffleModeRequestDtoToJson(this);
}
