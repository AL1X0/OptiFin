// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_storage_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LibraryStorageDto _$LibraryStorageDtoFromJson(Map<String, dynamic> json) =>
    LibraryStorageDto(
      id: json['Id'] as String,
      name: json['Name'] as String,
      folders: (json['Folders'] as List<dynamic>)
          .map((e) => FolderStorageDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$LibraryStorageDtoToJson(LibraryStorageDto instance) =>
    <String, dynamic>{
      'Id': instance.id,
      'Name': instance.name,
      'Folders': instance.folders,
    };
