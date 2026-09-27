// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceProfile _$DeviceProfileFromJson(Map<String, dynamic> json) =>
    DeviceProfile(
      name: json['Name'] as String?,
      id: json['Id'] as String?,
      maxStreamingBitrate: (json['MaxStreamingBitrate'] as num?)?.toInt(),
      maxStaticBitrate: (json['MaxStaticBitrate'] as num?)?.toInt(),
      musicStreamingTranscodingBitrate:
          (json['MusicStreamingTranscodingBitrate'] as num?)?.toInt(),
      maxStaticMusicBitrate: (json['MaxStaticMusicBitrate'] as num?)?.toInt(),
      directPlayProfiles: (json['DirectPlayProfiles'] as List<dynamic>?)
          ?.map((e) => DirectPlayProfile.fromJson(e as Map<String, dynamic>))
          .toList(),
      transcodingProfiles: (json['TranscodingProfiles'] as List<dynamic>?)
          ?.map((e) => TranscodingProfile.fromJson(e as Map<String, dynamic>))
          .toList(),
      containerProfiles: (json['ContainerProfiles'] as List<dynamic>?)
          ?.map((e) => ContainerProfile.fromJson(e as Map<String, dynamic>))
          .toList(),
      codecProfiles: (json['CodecProfiles'] as List<dynamic>?)
          ?.map((e) => CodecProfile.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtitleProfiles: (json['SubtitleProfiles'] as List<dynamic>?)
          ?.map((e) => SubtitleProfile.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$DeviceProfileToJson(DeviceProfile instance) =>
    <String, dynamic>{
      'Name': ?instance.name,
      'Id': ?instance.id,
      'MaxStreamingBitrate': ?instance.maxStreamingBitrate,
      'MaxStaticBitrate': ?instance.maxStaticBitrate,
      'MusicStreamingTranscodingBitrate':
          ?instance.musicStreamingTranscodingBitrate,
      'MaxStaticMusicBitrate': ?instance.maxStaticMusicBitrate,
      'DirectPlayProfiles': ?instance.directPlayProfiles,
      'TranscodingProfiles': ?instance.transcodingProfiles,
      'ContainerProfiles': ?instance.containerProfiles,
      'CodecProfiles': ?instance.codecProfiles,
      'SubtitleProfiles': ?instance.subtitleProfiles,
    };
