// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_capabilities_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClientCapabilitiesDto _$ClientCapabilitiesDtoFromJson(
  Map<String, dynamic> json,
) => ClientCapabilitiesDto(
  playableMediaTypes: (json['PlayableMediaTypes'] as List<dynamic>)
      .map(MediaType.fromJson)
      .toList(),
  supportedCommands: (json['SupportedCommands'] as List<dynamic>)
      .map((e) => GeneralCommandType.fromJson(e as String))
      .toList(),
  supportsMediaControl: json['SupportsMediaControl'] as bool,
  supportsPersistentIdentifier: json['SupportsPersistentIdentifier'] as bool,
  deviceProfile: json['DeviceProfile'] == null
      ? null
      : DeviceProfile.fromJson(json['DeviceProfile'] as Map<String, dynamic>),
  appStoreUrl: json['AppStoreUrl'] as String?,
  iconUrl: json['IconUrl'] as String?,
);

Map<String, dynamic> _$ClientCapabilitiesDtoToJson(
  ClientCapabilitiesDto instance,
) => <String, dynamic>{
  'PlayableMediaTypes': instance.playableMediaTypes,
  'SupportedCommands': instance.supportedCommands,
  'SupportsMediaControl': instance.supportsMediaControl,
  'SupportsPersistentIdentifier': instance.supportsPersistentIdentifier,
  'DeviceProfile': instance.deviceProfile,
  'AppStoreUrl': instance.appStoreUrl,
  'IconUrl': instance.iconUrl,
};
