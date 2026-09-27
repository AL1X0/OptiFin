// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lyric_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LyricDto _$LyricDtoFromJson(Map<String, dynamic> json) => LyricDto(
  metadata: json['Metadata'] == null
      ? null
      : LyricMetadata.fromJson(json['Metadata'] as Map<String, dynamic>),
  lyrics: (json['Lyrics'] as List<dynamic>?)
      ?.map((e) => LyricLine.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$LyricDtoToJson(LyricDto instance) => <String, dynamic>{
  'Metadata': instance.metadata,
  'Lyrics': instance.lyrics,
};
