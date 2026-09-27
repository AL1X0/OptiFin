// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_stream_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LiveStreamResponse _$LiveStreamResponseFromJson(Map<String, dynamic> json) =>
    LiveStreamResponse(
      mediaSource: json['MediaSource'] == null
          ? null
          : MediaSourceInfo.fromJson(
              json['MediaSource'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$LiveStreamResponseToJson(LiveStreamResponse instance) =>
    <String, dynamic>{'MediaSource': ?instance.mediaSource};
