// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'set_channel_mapping_dto.g.dart';

/// Set channel mapping dto.
@JsonSerializable()
class SetChannelMappingDto {
  const SetChannelMappingDto({
    this.providerId,
    this.tunerChannelId,
    this.providerChannelId,
  });
  
  factory SetChannelMappingDto.fromJson(Map<String, Object?> json) => _$SetChannelMappingDtoFromJson(json);
  
  /// Gets or sets the provider id.
  @JsonKey(name: 'ProviderId')
  final String? providerId;

  /// Gets or sets the tuner channel id.
  @JsonKey(name: 'TunerChannelId')
  final String? tunerChannelId;

  /// Gets or sets the provider channel id.
  @JsonKey(name: 'ProviderChannelId')
  final String? providerChannelId;

  Map<String, Object?> toJson() => _$SetChannelMappingDtoToJson(this);
}
