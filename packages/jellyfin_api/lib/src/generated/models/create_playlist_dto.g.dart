// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_playlist_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreatePlaylistDto _$CreatePlaylistDtoFromJson(Map<String, dynamic> json) =>
    CreatePlaylistDto(
      name: json['Name'] as String?,
      ids: (json['Ids'] as List<dynamic>?)?.map((e) => e as String).toList(),
      userId: json['UserId'] as String?,
      mediaType: json['MediaType'] == null
          ? null
          : CreatePlaylistDtoMediaType.fromJson(json['MediaType']),
      users: (json['Users'] as List<dynamic>?)
          ?.map(
            (e) => PlaylistUserPermissions.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      isPublic: json['IsPublic'] as bool?,
    );

Map<String, dynamic> _$CreatePlaylistDtoToJson(CreatePlaylistDto instance) =>
    <String, dynamic>{
      'Name': instance.name,
      'Ids': instance.ids,
      'UserId': instance.userId,
      'MediaType': instance.mediaType,
      'Users': instance.users,
      'IsPublic': instance.isPublic,
    };
