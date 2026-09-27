// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_channel_mapping_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SetChannelMappingDto _$SetChannelMappingDtoFromJson(
  Map<String, dynamic> json,
) => SetChannelMappingDto(
  providerId: json['ProviderId'] as String?,
  tunerChannelId: json['TunerChannelId'] as String?,
  providerChannelId: json['ProviderChannelId'] as String?,
);

Map<String, dynamic> _$SetChannelMappingDtoToJson(
  SetChannelMappingDto instance,
) => <String, dynamic>{
  'ProviderId': ?instance.providerId,
  'TunerChannelId': ?instance.tunerChannelId,
  'ProviderChannelId': ?instance.providerChannelId,
};
