// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remote_lyric_info_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RemoteLyricInfoDto _$RemoteLyricInfoDtoFromJson(Map<String, dynamic> json) =>
    RemoteLyricInfoDto(
      id: json['Id'] as String,
      providerName: json['ProviderName'] as String?,
      lyrics: json['Lyrics'] == null
          ? null
          : LyricDto.fromJson(json['Lyrics'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$RemoteLyricInfoDtoToJson(RemoteLyricInfoDto instance) =>
    <String, dynamic>{
      'Id': instance.id,
      'ProviderName': instance.providerName,
      'Lyrics': instance.lyrics,
    };
