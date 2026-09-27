// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'library_option_info_dto.dart';
import 'library_type_options_dto.dart';

part 'library_options_result_dto.g.dart';

/// Library options result dto.
@JsonSerializable()
class LibraryOptionsResultDto {
  const LibraryOptionsResultDto({
    this.metadataSavers,
    this.metadataReaders,
    this.subtitleFetchers,
    this.lyricFetchers,
    this.mediaSegmentProviders,
    this.typeOptions,
  });
  
  factory LibraryOptionsResultDto.fromJson(Map<String, Object?> json) => _$LibraryOptionsResultDtoFromJson(json);
  
  /// Gets or sets the metadata savers.
  @JsonKey(name: 'MetadataSavers')
  final List<LibraryOptionInfoDto>? metadataSavers;

  /// Gets or sets the metadata readers.
  @JsonKey(name: 'MetadataReaders')
  final List<LibraryOptionInfoDto>? metadataReaders;

  /// Gets or sets the subtitle fetchers.
  @JsonKey(name: 'SubtitleFetchers')
  final List<LibraryOptionInfoDto>? subtitleFetchers;

  /// Gets or sets the list of lyric fetchers.
  @JsonKey(name: 'LyricFetchers')
  final List<LibraryOptionInfoDto>? lyricFetchers;

  /// Gets or sets the list of MediaSegment Providers.
  @JsonKey(name: 'MediaSegmentProviders')
  final List<LibraryOptionInfoDto>? mediaSegmentProviders;

  /// Gets or sets the type options.
  @JsonKey(name: 'TypeOptions')
  final List<LibraryTypeOptionsDto>? typeOptions;

  Map<String, Object?> toJson() => _$LibraryOptionsResultDtoToJson(this);
}
