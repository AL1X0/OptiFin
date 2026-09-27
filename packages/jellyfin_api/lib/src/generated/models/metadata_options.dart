// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'metadata_options.g.dart';

/// Class MetadataOptions.
@JsonSerializable()
class MetadataOptions {
  const MetadataOptions({
    this.itemType,
    this.disabledMetadataSavers,
    this.localMetadataReaderOrder,
    this.disabledMetadataFetchers,
    this.metadataFetcherOrder,
    this.disabledImageFetchers,
    this.imageFetcherOrder,
  });
  
  factory MetadataOptions.fromJson(Map<String, Object?> json) => _$MetadataOptionsFromJson(json);
  
  @JsonKey(name: 'ItemType')
  final String? itemType;
  @JsonKey(name: 'DisabledMetadataSavers')
  final List<String>? disabledMetadataSavers;
  @JsonKey(name: 'LocalMetadataReaderOrder')
  final List<String>? localMetadataReaderOrder;
  @JsonKey(name: 'DisabledMetadataFetchers')
  final List<String>? disabledMetadataFetchers;
  @JsonKey(name: 'MetadataFetcherOrder')
  final List<String>? metadataFetcherOrder;
  @JsonKey(name: 'DisabledImageFetchers')
  final List<String>? disabledImageFetchers;
  @JsonKey(name: 'ImageFetcherOrder')
  final List<String>? imageFetcherOrder;

  Map<String, Object?> toJson() => _$MetadataOptionsToJson(this);
}
