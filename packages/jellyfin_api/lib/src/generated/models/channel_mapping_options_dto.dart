// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'name_id_pair.dart';
import 'name_value_pair.dart';
import 'tuner_channel_mapping.dart';

part 'channel_mapping_options_dto.g.dart';

/// Channel mapping options dto.
@JsonSerializable()
class ChannelMappingOptionsDto {
  const ChannelMappingOptionsDto({
    this.tunerChannels,
    this.providerChannels,
    this.mappings,
    this.providerName,
  });
  
  factory ChannelMappingOptionsDto.fromJson(Map<String, Object?> json) => _$ChannelMappingOptionsDtoFromJson(json);
  
  /// Gets or sets list of tuner channels.
  @JsonKey(name: 'TunerChannels')
  final List<TunerChannelMapping>? tunerChannels;

  /// Gets or sets list of provider channels.
  @JsonKey(name: 'ProviderChannels')
  final List<NameIdPair>? providerChannels;

  /// Gets or sets list of mappings.
  @JsonKey(name: 'Mappings')
  final List<NameValuePair>? mappings;

  /// Gets or sets provider name.
  @JsonKey(name: 'ProviderName')
  final String? providerName;

  Map<String, Object?> toJson() => _$ChannelMappingOptionsDtoToJson(this);
}
