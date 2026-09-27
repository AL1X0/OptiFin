// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'queue_request_dto_mode.dart';

part 'queue_request_dto.g.dart';

/// Class QueueRequestDto.
@JsonSerializable()
class QueueRequestDto {
  const QueueRequestDto({
    required this.itemIds,
    required this.mode,
  });
  
  factory QueueRequestDto.fromJson(Map<String, Object?> json) => _$QueueRequestDtoFromJson(json);
  
  /// Gets or sets the items to enqueue.
  @JsonKey(name: 'ItemIds')
  final List<String> itemIds;

  /// Gets or sets the mode in which to add the new items.
  @JsonKey(name: 'Mode')
  final QueueRequestDtoMode mode;

  Map<String, Object?> toJson() => _$QueueRequestDtoToJson(this);
}
