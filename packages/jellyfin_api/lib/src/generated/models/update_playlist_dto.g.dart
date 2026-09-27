// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_playlist_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdatePlaylistDto _$UpdatePlaylistDtoFromJson(Map<String, dynamic> json) =>
    UpdatePlaylistDto(
      name: json['Name'] as String?,
      ids: (json['Ids'] as List<dynamic>?)?.map((e) => e as String).toList(),
      users: (json['Users'] as List<dynamic>?)
          ?.map(
            (e) => PlaylistUserPermissions.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      isPublic: json['IsPublic'] as bool?,
    );

Map<String, dynamic> _$UpdatePlaylistDtoToJson(UpdatePlaylistDto instance) =>
    <String, dynamic>{
      'Name': instance.name,
      'Ids': instance.ids,
      'Users': instance.users,
      'IsPublic': instance.isPublic,
    };
