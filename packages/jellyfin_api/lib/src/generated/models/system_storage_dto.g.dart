// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_storage_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SystemStorageDto _$SystemStorageDtoFromJson(Map<String, dynamic> json) =>
    SystemStorageDto(
      programDataFolder: FolderStorageDto.fromJson(
        json['ProgramDataFolder'] as Map<String, dynamic>,
      ),
      webFolder: FolderStorageDto.fromJson(
        json['WebFolder'] as Map<String, dynamic>,
      ),
      imageCacheFolder: FolderStorageDto.fromJson(
        json['ImageCacheFolder'] as Map<String, dynamic>,
      ),
      cacheFolder: FolderStorageDto.fromJson(
        json['CacheFolder'] as Map<String, dynamic>,
      ),
      logFolder: FolderStorageDto.fromJson(
        json['LogFolder'] as Map<String, dynamic>,
      ),
      internalMetadataFolder: FolderStorageDto.fromJson(
        json['InternalMetadataFolder'] as Map<String, dynamic>,
      ),
      transcodingTempFolder: FolderStorageDto.fromJson(
        json['TranscodingTempFolder'] as Map<String, dynamic>,
      ),
      libraries: (json['Libraries'] as List<dynamic>)
          .map((e) => LibraryStorageDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SystemStorageDtoToJson(SystemStorageDto instance) =>
    <String, dynamic>{
      'ProgramDataFolder': instance.programDataFolder,
      'WebFolder': instance.webFolder,
      'ImageCacheFolder': instance.imageCacheFolder,
      'CacheFolder': instance.cacheFolder,
      'LogFolder': instance.logFolder,
      'InternalMetadataFolder': instance.internalMetadataFolder,
      'TranscodingTempFolder': instance.transcodingTempFolder,
      'Libraries': instance.libraries,
    };
