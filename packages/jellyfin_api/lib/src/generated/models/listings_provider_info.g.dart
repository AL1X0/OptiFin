// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'listings_provider_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListingsProviderInfo _$ListingsProviderInfoFromJson(
  Map<String, dynamic> json,
) => ListingsProviderInfo(
  id: json['Id'] as String?,
  type: json['Type'] as String?,
  username: json['Username'] as String?,
  password: json['Password'] as String?,
  listingsId: json['ListingsId'] as String?,
  zipCode: json['ZipCode'] as String?,
  country: json['Country'] as String?,
  path: json['Path'] as String?,
  enabledTuners: (json['EnabledTuners'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  enableAllTuners: json['EnableAllTuners'] as bool?,
  newsCategories: (json['NewsCategories'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  sportsCategories: (json['SportsCategories'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  kidsCategories: (json['KidsCategories'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  movieCategories: (json['MovieCategories'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  channelMappings: (json['ChannelMappings'] as List<dynamic>?)
      ?.map((e) => NameValuePair.fromJson(e as Map<String, dynamic>))
      .toList(),
  moviePrefix: json['MoviePrefix'] as String?,
  preferredLanguage: json['PreferredLanguage'] as String?,
  userAgent: json['UserAgent'] as String?,
);

Map<String, dynamic> _$ListingsProviderInfoToJson(
  ListingsProviderInfo instance,
) => <String, dynamic>{
  'Id': ?instance.id,
  'Type': ?instance.type,
  'Username': ?instance.username,
  'Password': ?instance.password,
  'ListingsId': ?instance.listingsId,
  'ZipCode': ?instance.zipCode,
  'Country': ?instance.country,
  'Path': ?instance.path,
  'EnabledTuners': ?instance.enabledTuners,
  'EnableAllTuners': ?instance.enableAllTuners,
  'NewsCategories': ?instance.newsCategories,
  'SportsCategories': ?instance.sportsCategories,
  'KidsCategories': ?instance.kidsCategories,
  'MovieCategories': ?instance.movieCategories,
  'ChannelMappings': ?instance.channelMappings,
  'MoviePrefix': ?instance.moviePrefix,
  'PreferredLanguage': ?instance.preferredLanguage,
  'UserAgent': ?instance.userAgent,
};
