// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'folder_storage_dto.g.dart';

/// Contains information about a specific folder.
@JsonSerializable()
class FolderStorageDto {
  const FolderStorageDto({
    this.path,
    this.freeSpace,
    this.usedSpace,
    this.storageType,
    this.deviceId,
  });
  
  factory FolderStorageDto.fromJson(Map<String, Object?> json) => _$FolderStorageDtoFromJson(json);
  
  /// Gets the path of the folder in question.
  @JsonKey(name: 'Path')
  final String? path;

  /// Gets the free space of the underlying storage device of the Jellyfin.Api.Models.SystemInfoDtos.FolderStorageDto.Path.
  @JsonKey(name: 'FreeSpace')
  final int? freeSpace;

  /// Gets the used space of the underlying storage device of the Jellyfin.Api.Models.SystemInfoDtos.FolderStorageDto.Path.
  @JsonKey(name: 'UsedSpace')
  final int? usedSpace;

  /// Gets the kind of storage device of the Jellyfin.Api.Models.SystemInfoDtos.FolderStorageDto.Path.
  @JsonKey(name: 'StorageType')
  final String? storageType;

  /// Gets the Device Identifier.
  @JsonKey(name: 'DeviceId')
  final String? deviceId;

  Map<String, Object?> toJson() => _$FolderStorageDtoToJson(this);
}
