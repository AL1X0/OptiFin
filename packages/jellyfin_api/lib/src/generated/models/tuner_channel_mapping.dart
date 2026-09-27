// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'tuner_channel_mapping.g.dart';

@JsonSerializable()
class TunerChannelMapping {
  const TunerChannelMapping({
    this.name,
    this.providerChannelName,
    this.providerChannelId,
    this.id,
  });
  
  factory TunerChannelMapping.fromJson(Map<String, Object?> json) => _$TunerChannelMappingFromJson(json);
  
  @JsonKey(name: 'Name')
  final String? name;
  @JsonKey(name: 'ProviderChannelName')
  final String? providerChannelName;
  @JsonKey(name: 'ProviderChannelId')
  final String? providerChannelId;
  @JsonKey(name: 'Id')
  final String? id;

  Map<String, Object?> toJson() => _$TunerChannelMappingToJson(this);
}
