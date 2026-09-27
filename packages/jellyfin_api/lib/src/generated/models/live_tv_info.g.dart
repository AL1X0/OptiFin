// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_tv_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LiveTvInfo _$LiveTvInfoFromJson(Map<String, dynamic> json) => LiveTvInfo(
  services: (json['Services'] as List<dynamic>?)
      ?.map((e) => LiveTvServiceInfo.fromJson(e as Map<String, dynamic>))
      .toList(),
  isEnabled: json['IsEnabled'] as bool?,
  enabledUsers: (json['EnabledUsers'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$LiveTvInfoToJson(LiveTvInfo instance) =>
    <String, dynamic>{
      'Services': instance.services,
      'IsEnabled': instance.isEnabled,
      'EnabledUsers': instance.enabledUsers,
    };
