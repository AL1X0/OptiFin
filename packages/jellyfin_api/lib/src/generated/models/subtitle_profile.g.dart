// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subtitle_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubtitleProfile _$SubtitleProfileFromJson(Map<String, dynamic> json) =>
    SubtitleProfile(
      format: json['Format'] as String?,
      method: SubtitleProfileMethod.fromJson(json['Method']),
      didlMode: json['DidlMode'] as String?,
      language: json['Language'] as String?,
      container: json['Container'] as String?,
    );

Map<String, dynamic> _$SubtitleProfileToJson(SubtitleProfile instance) =>
    <String, dynamic>{
      'Format': instance.format,
      'Method': instance.method,
      'DidlMode': instance.didlMode,
      'Language': instance.language,
      'Container': instance.container,
    };
