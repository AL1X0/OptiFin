// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'playlist_creation_result.g.dart';

@JsonSerializable()
class PlaylistCreationResult {
  const PlaylistCreationResult({
    this.id,
  });
  
  factory PlaylistCreationResult.fromJson(Map<String, Object?> json) => _$PlaylistCreationResultFromJson(json);
  
  @JsonKey(name: 'Id')
  final String? id;

  Map<String, Object?> toJson() => _$PlaylistCreationResultToJson(this);
}
