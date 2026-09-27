// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'name_value_pair.dart';

part 'listings_provider_info.g.dart';

@JsonSerializable()
class ListingsProviderInfo {
  const ListingsProviderInfo({
    this.id,
    this.type,
    this.username,
    this.password,
    this.listingsId,
    this.zipCode,
    this.country,
    this.path,
    this.enabledTuners,
    this.enableAllTuners,
    this.newsCategories,
    this.sportsCategories,
    this.kidsCategories,
    this.movieCategories,
    this.channelMappings,
    this.moviePrefix,
    this.preferredLanguage,
    this.userAgent,
  });
  
  factory ListingsProviderInfo.fromJson(Map<String, Object?> json) => _$ListingsProviderInfoFromJson(json);
  
  @JsonKey(name: 'Id')
  final String? id;
  @JsonKey(name: 'Type')
  final String? type;
  @JsonKey(name: 'Username')
  final String? username;
  @JsonKey(name: 'Password')
  final String? password;
  @JsonKey(name: 'ListingsId')
  final String? listingsId;
  @JsonKey(name: 'ZipCode')
  final String? zipCode;
  @JsonKey(name: 'Country')
  final String? country;
  @JsonKey(name: 'Path')
  final String? path;
  @JsonKey(name: 'EnabledTuners')
  final List<String>? enabledTuners;
  @JsonKey(name: 'EnableAllTuners')
  final bool? enableAllTuners;
  @JsonKey(name: 'NewsCategories')
  final List<String>? newsCategories;
  @JsonKey(name: 'SportsCategories')
  final List<String>? sportsCategories;
  @JsonKey(name: 'KidsCategories')
  final List<String>? kidsCategories;
  @JsonKey(name: 'MovieCategories')
  final List<String>? movieCategories;
  @JsonKey(name: 'ChannelMappings')
  final List<NameValuePair>? channelMappings;
  @JsonKey(name: 'MoviePrefix')
  final String? moviePrefix;
  @JsonKey(name: 'PreferredLanguage')
  final String? preferredLanguage;
  @JsonKey(name: 'UserAgent')
  final String? userAgent;

  Map<String, Object?> toJson() => _$ListingsProviderInfoToJson(this);
}
