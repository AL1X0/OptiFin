// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upload_subtitle_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UploadSubtitleDto _$UploadSubtitleDtoFromJson(Map<String, dynamic> json) =>
    UploadSubtitleDto(
      language: json['Language'] as String?,
      format: json['Format'] as String?,
      isForced: json['IsForced'] as bool?,
      isHearingImpaired: json['IsHearingImpaired'] as bool?,
      data: json['Data'] as String?,
    );

Map<String, dynamic> _$UploadSubtitleDtoToJson(UploadSubtitleDto instance) =>
    <String, dynamic>{
      'Language': ?instance.language,
      'Format': ?instance.format,
      'IsForced': ?instance.isForced,
      'IsHearingImpaired': ?instance.isHearingImpaired,
      'Data': ?instance.data,
    };
