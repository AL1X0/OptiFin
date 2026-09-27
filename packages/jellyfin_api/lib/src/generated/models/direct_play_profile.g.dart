// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'direct_play_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DirectPlayProfile _$DirectPlayProfileFromJson(Map<String, dynamic> json) =>
    DirectPlayProfile(
      container: json['Container'] as String?,
      audioCodec: json['AudioCodec'] as String?,
      videoCodec: json['VideoCodec'] as String?,
      type: json['Type'] == null
          ? null
          : DirectPlayProfileType.fromJson(json['Type']),
    );

Map<String, dynamic> _$DirectPlayProfileToJson(DirectPlayProfile instance) =>
    <String, dynamic>{
      'Container': ?instance.container,
      'AudioCodec': ?instance.audioCodec,
      'VideoCodec': ?instance.videoCodec,
      'Type': ?instance.type,
    };
