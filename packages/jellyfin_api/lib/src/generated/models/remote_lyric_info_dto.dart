// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'lyric_dto.dart';

part 'remote_lyric_info_dto.g.dart';

/// The remote lyric info dto.
@JsonSerializable()
class RemoteLyricInfoDto {
  const RemoteLyricInfoDto({
    required this.id,
    required this.providerName,
    required this.lyrics,
  });
  
  factory RemoteLyricInfoDto.fromJson(Map<String, Object?> json) => _$RemoteLyricInfoDtoFromJson(json);
  
  /// Gets or sets the id for the lyric.
  @JsonKey(name: 'Id')
  final String id;

  /// Gets the provider name.
  @JsonKey(name: 'ProviderName')
  final String providerName;

  /// Gets the lyrics.
  @JsonKey(name: 'Lyrics')
  final LyricDto lyrics;

  Map<String, Object?> toJson() => _$RemoteLyricInfoDtoToJson(this);
}
