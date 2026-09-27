// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ready_request_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReadyRequestDto _$ReadyRequestDtoFromJson(Map<String, dynamic> json) =>
    ReadyRequestDto(
      whenValue: json['When'] == null
          ? null
          : DateTime.parse(json['When'] as String),
      positionTicks: (json['PositionTicks'] as num?)?.toInt(),
      isPlaying: json['IsPlaying'] as bool?,
      playlistItemId: json['PlaylistItemId'] as String?,
    );

Map<String, dynamic> _$ReadyRequestDtoToJson(ReadyRequestDto instance) =>
    <String, dynamic>{
      'When': ?instance.whenValue?.toIso8601String(),
      'PositionTicks': ?instance.positionTicks,
      'IsPlaying': ?instance.isPlaying,
      'PlaylistItemId': ?instance.playlistItemId,
    };
