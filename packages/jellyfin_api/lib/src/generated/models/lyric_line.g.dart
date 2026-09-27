// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lyric_line.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LyricLine _$LyricLineFromJson(Map<String, dynamic> json) => LyricLine(
  text: json['Text'] as String?,
  start: (json['Start'] as num?)?.toInt(),
  cues: (json['Cues'] as List<dynamic>?)
      ?.map((e) => LyricLineCue.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$LyricLineToJson(LyricLine instance) => <String, dynamic>{
  'Text': instance.text,
  'Start': instance.start,
  'Cues': instance.cues,
};
