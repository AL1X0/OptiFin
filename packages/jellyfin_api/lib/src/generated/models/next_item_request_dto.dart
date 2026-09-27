// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'next_item_request_dto.g.dart';

/// Class NextItemRequestDto.
@JsonSerializable()
class NextItemRequestDto {
  const NextItemRequestDto({
    this.playlistItemId,
  });
  
  factory NextItemRequestDto.fromJson(Map<String, Object?> json) => _$NextItemRequestDtoFromJson(json);
  
  /// Gets or sets the playing item identifier.
  @JsonKey(name: 'PlaylistItemId')
  final String? playlistItemId;

  Map<String, Object?> toJson() => _$NextItemRequestDtoToJson(this);
}
