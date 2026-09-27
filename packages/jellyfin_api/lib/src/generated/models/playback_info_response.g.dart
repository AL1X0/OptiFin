// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_info_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlaybackInfoResponse _$PlaybackInfoResponseFromJson(
  Map<String, dynamic> json,
) => PlaybackInfoResponse(
  mediaSources: (json['MediaSources'] as List<dynamic>?)
      ?.map((e) => MediaSourceInfo.fromJson(e as Map<String, dynamic>))
      .toList(),
  playSessionId: json['PlaySessionId'] as String?,
  errorCode: json['ErrorCode'] == null
      ? null
      : PlaybackInfoResponseErrorCode.fromJson(json['ErrorCode']),
);

Map<String, dynamic> _$PlaybackInfoResponseToJson(
  PlaybackInfoResponse instance,
) => <String, dynamic>{
  'MediaSources': ?instance.mediaSources,
  'PlaySessionId': ?instance.playSessionId,
  'ErrorCode': ?instance.errorCode,
};
