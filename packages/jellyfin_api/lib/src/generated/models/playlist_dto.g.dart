// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlaylistDto _$PlaylistDtoFromJson(Map<String, dynamic> json) => PlaylistDto(
  shares: (json['Shares'] as List<dynamic>)
      .map((e) => PlaylistUserPermissions.fromJson(e as Map<String, dynamic>))
      .toList(),
  itemIds: (json['ItemIds'] as List<dynamic>).map((e) => e as String).toList(),
  openAccess: json['OpenAccess'] as bool?,
);

Map<String, dynamic> _$PlaylistDtoToJson(PlaylistDto instance) =>
    <String, dynamic>{
      'OpenAccess': instance.openAccess,
      'Shares': instance.shares,
      'ItemIds': instance.itemIds,
    };
