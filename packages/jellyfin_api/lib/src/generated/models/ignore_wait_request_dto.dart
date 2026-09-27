// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'ignore_wait_request_dto.g.dart';

/// Class IgnoreWaitRequestDto.
@JsonSerializable()
class IgnoreWaitRequestDto {
  const IgnoreWaitRequestDto({
    this.ignoreWait,
  });
  
  factory IgnoreWaitRequestDto.fromJson(Map<String, Object?> json) => _$IgnoreWaitRequestDtoFromJson(json);
  
  /// Gets or sets a value indicating whether the client should be ignored.
  @JsonKey(name: 'IgnoreWait')
  final bool? ignoreWait;

  Map<String, Object?> toJson() => _$IgnoreWaitRequestDtoToJson(this);
}
