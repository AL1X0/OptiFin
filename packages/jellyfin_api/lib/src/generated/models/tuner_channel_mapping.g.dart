// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tuner_channel_mapping.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TunerChannelMapping _$TunerChannelMappingFromJson(Map<String, dynamic> json) =>
    TunerChannelMapping(
      name: json['Name'] as String?,
      providerChannelName: json['ProviderChannelName'] as String?,
      providerChannelId: json['ProviderChannelId'] as String?,
      id: json['Id'] as String?,
    );

Map<String, dynamic> _$TunerChannelMappingToJson(
  TunerChannelMapping instance,
) => <String, dynamic>{
  'Name': ?instance.name,
  'ProviderChannelName': ?instance.providerChannelName,
  'ProviderChannelId': ?instance.providerChannelId,
  'Id': ?instance.id,
};
