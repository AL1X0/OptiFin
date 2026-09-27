// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'image_option.dart';
import 'image_type.dart';
import 'library_option_info_dto.dart';

part 'library_type_options_dto.g.dart';

/// Library type options dto.
@JsonSerializable()
class LibraryTypeOptionsDto {
  const LibraryTypeOptionsDto({
    this.type,
    this.metadataFetchers,
    this.imageFetchers,
    this.similarItemProviders,
    this.supportedImageTypes,
    this.defaultImageOptions,
  });
  
  factory LibraryTypeOptionsDto.fromJson(Map<String, Object?> json) => _$LibraryTypeOptionsDtoFromJson(json);
  
  /// Gets or sets the type.
  @JsonKey(name: 'Type')
  final String? type;

  /// Gets or sets the metadata fetchers.
  @JsonKey(name: 'MetadataFetchers')
  final List<LibraryOptionInfoDto>? metadataFetchers;

  /// Gets or sets the image fetchers.
  @JsonKey(name: 'ImageFetchers')
  final List<LibraryOptionInfoDto>? imageFetchers;

  /// Gets or sets the similar item providers.
  @JsonKey(name: 'SimilarItemProviders')
  final List<LibraryOptionInfoDto>? similarItemProviders;

  /// Gets or sets the supported image types.
  @JsonKey(name: 'SupportedImageTypes')
  final List<ImageType>? supportedImageTypes;

  /// Gets or sets the default image options.
  @JsonKey(name: 'DefaultImageOptions')
  final List<ImageOption>? defaultImageOptions;

  Map<String, Object?> toJson() => _$LibraryTypeOptionsDtoToJson(this);
}
