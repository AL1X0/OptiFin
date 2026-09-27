// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_options_result_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LibraryOptionsResultDto _$LibraryOptionsResultDtoFromJson(
  Map<String, dynamic> json,
) => LibraryOptionsResultDto(
  metadataSavers: (json['MetadataSavers'] as List<dynamic>?)
      ?.map((e) => LibraryOptionInfoDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  metadataReaders: (json['MetadataReaders'] as List<dynamic>?)
      ?.map((e) => LibraryOptionInfoDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  subtitleFetchers: (json['SubtitleFetchers'] as List<dynamic>?)
      ?.map((e) => LibraryOptionInfoDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  lyricFetchers: (json['LyricFetchers'] as List<dynamic>?)
      ?.map((e) => LibraryOptionInfoDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  mediaSegmentProviders: (json['MediaSegmentProviders'] as List<dynamic>?)
      ?.map((e) => LibraryOptionInfoDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  typeOptions: (json['TypeOptions'] as List<dynamic>?)
      ?.map((e) => LibraryTypeOptionsDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$LibraryOptionsResultDtoToJson(
  LibraryOptionsResultDto instance,
) => <String, dynamic>{
  'MetadataSavers': instance.metadataSavers,
  'MetadataReaders': instance.metadataReaders,
  'SubtitleFetchers': instance.subtitleFetchers,
  'LyricFetchers': instance.lyricFetchers,
  'MediaSegmentProviders': instance.mediaSegmentProviders,
  'TypeOptions': instance.typeOptions,
};
