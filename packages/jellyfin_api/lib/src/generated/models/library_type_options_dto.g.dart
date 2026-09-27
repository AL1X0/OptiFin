// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_type_options_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LibraryTypeOptionsDto _$LibraryTypeOptionsDtoFromJson(
  Map<String, dynamic> json,
) => LibraryTypeOptionsDto(
  type: json['Type'] as String?,
  metadataFetchers: (json['MetadataFetchers'] as List<dynamic>?)
      ?.map((e) => LibraryOptionInfoDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  imageFetchers: (json['ImageFetchers'] as List<dynamic>?)
      ?.map((e) => LibraryOptionInfoDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  similarItemProviders: (json['SimilarItemProviders'] as List<dynamic>?)
      ?.map((e) => LibraryOptionInfoDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  supportedImageTypes: (json['SupportedImageTypes'] as List<dynamic>?)
      ?.map((e) => ImageType.fromJson(e as String))
      .toList(),
  defaultImageOptions: (json['DefaultImageOptions'] as List<dynamic>?)
      ?.map((e) => ImageOption.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$LibraryTypeOptionsDtoToJson(
  LibraryTypeOptionsDto instance,
) => <String, dynamic>{
  'Type': ?instance.type,
  'MetadataFetchers': ?instance.metadataFetchers,
  'ImageFetchers': ?instance.imageFetchers,
  'SimilarItemProviders': ?instance.similarItemProviders,
  'SupportedImageTypes': ?instance.supportedImageTypes,
  'DefaultImageOptions': ?instance.defaultImageOptions,
};
