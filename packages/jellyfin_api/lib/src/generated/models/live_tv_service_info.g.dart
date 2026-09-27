// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_tv_service_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LiveTvServiceInfo _$LiveTvServiceInfoFromJson(Map<String, dynamic> json) =>
    LiveTvServiceInfo(
      name: json['Name'] as String?,
      homePageUrl: json['HomePageUrl'] as String?,
      status: json['Status'] == null
          ? null
          : LiveTvServiceInfoStatus.fromJson(json['Status']),
      statusMessage: json['StatusMessage'] as String?,
      version: json['Version'] as String?,
      hasUpdateAvailable: json['HasUpdateAvailable'] as bool?,
      isVisible: json['IsVisible'] as bool?,
      tuners: (json['Tuners'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$LiveTvServiceInfoToJson(LiveTvServiceInfo instance) =>
    <String, dynamic>{
      'Name': ?instance.name,
      'HomePageUrl': ?instance.homePageUrl,
      'Status': ?instance.status,
      'StatusMessage': ?instance.statusMessage,
      'Version': ?instance.version,
      'HasUpdateAvailable': ?instance.hasUpdateAvailable,
      'IsVisible': ?instance.isVisible,
      'Tuners': ?instance.tuners,
    };
