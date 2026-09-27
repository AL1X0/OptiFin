// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'device_profile.dart';
import 'general_command_type.dart';
import 'media_type.dart';

part 'client_capabilities_dto.g.dart';

/// Client capabilities dto.
@JsonSerializable()
class ClientCapabilitiesDto {
  const ClientCapabilitiesDto({
    required this.playableMediaTypes,
    required this.supportedCommands,
    required this.supportsMediaControl,
    required this.supportsPersistentIdentifier,
    required this.deviceProfile,
    required this.appStoreUrl,
    required this.iconUrl,
  });
  
  factory ClientCapabilitiesDto.fromJson(Map<String, Object?> json) => _$ClientCapabilitiesDtoFromJson(json);
  
  /// Gets or sets the list of playable media types.
  @JsonKey(name: 'PlayableMediaTypes')
  final List<MediaType>? playableMediaTypes;

  /// Gets or sets the list of supported commands.
  @JsonKey(name: 'SupportedCommands')
  final List<GeneralCommandType>? supportedCommands;

  /// Gets or sets a value indicating whether session supports media control.
  @JsonKey(name: 'SupportsMediaControl')
  final bool? supportsMediaControl;

  /// Gets or sets a value indicating whether session supports a persistent identifier.
  @JsonKey(name: 'SupportsPersistentIdentifier')
  final bool? supportsPersistentIdentifier;

  /// Gets or sets the device profile.
  @JsonKey(name: 'DeviceProfile')
  final DeviceProfile? deviceProfile;

  /// Gets or sets the app store url.
  @JsonKey(name: 'AppStoreUrl')
  final String? appStoreUrl;

  /// Gets or sets the icon url.
  @JsonKey(name: 'IconUrl')
  final String? iconUrl;

  Map<String, Object?> toJson() => _$ClientCapabilitiesDtoToJson(this);
}
