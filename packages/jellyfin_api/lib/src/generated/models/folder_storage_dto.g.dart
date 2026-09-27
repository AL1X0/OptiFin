// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'folder_storage_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FolderStorageDto _$FolderStorageDtoFromJson(Map<String, dynamic> json) =>
    FolderStorageDto(
      path: json['Path'] as String,
      freeSpace: (json['FreeSpace'] as num?)?.toInt(),
      usedSpace: (json['UsedSpace'] as num?)?.toInt(),
      storageType: json['StorageType'] as String?,
      deviceId: json['DeviceId'] as String?,
    );

Map<String, dynamic> _$FolderStorageDtoToJson(FolderStorageDto instance) =>
    <String, dynamic>{
      'Path': instance.path,
      'FreeSpace': instance.freeSpace,
      'UsedSpace': instance.usedSpace,
      'StorageType': instance.storageType,
      'DeviceId': instance.deviceId,
    };
