// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'folder_storage_dto.dart';
import 'library_storage_dto.dart';

part 'system_storage_dto.g.dart';

/// Contains informations about the systems storage.
@JsonSerializable()
class SystemStorageDto {
  const SystemStorageDto({
    required this.programDataFolder,
    required this.webFolder,
    required this.imageCacheFolder,
    required this.cacheFolder,
    required this.logFolder,
    required this.internalMetadataFolder,
    required this.transcodingTempFolder,
    required this.libraries,
  });
  
  factory SystemStorageDto.fromJson(Map<String, Object?> json) => _$SystemStorageDtoFromJson(json);
  
  /// Gets or sets the Storage information of the program data folder.
  @JsonKey(name: 'ProgramDataFolder')
  final FolderStorageDto? programDataFolder;

  /// Gets or sets the Storage information of the web UI resources folder.
  @JsonKey(name: 'WebFolder')
  final FolderStorageDto? webFolder;

  /// Gets or sets the Storage information of the folder where images are cached.
  @JsonKey(name: 'ImageCacheFolder')
  final FolderStorageDto? imageCacheFolder;

  /// Gets or sets the Storage information of the cache folder.
  @JsonKey(name: 'CacheFolder')
  final FolderStorageDto? cacheFolder;

  /// Gets or sets the Storage information of the folder where logfiles are saved to.
  @JsonKey(name: 'LogFolder')
  final FolderStorageDto? logFolder;

  /// Gets or sets the Storage information of the folder where metadata is stored.
  @JsonKey(name: 'InternalMetadataFolder')
  final FolderStorageDto? internalMetadataFolder;

  /// Gets or sets the Storage information of the transcoding cache.
  @JsonKey(name: 'TranscodingTempFolder')
  final FolderStorageDto? transcodingTempFolder;

  /// Gets or sets the storage informations of all libraries.
  @JsonKey(name: 'Libraries')
  final List<LibraryStorageDto>? libraries;

  Map<String, Object?> toJson() => _$SystemStorageDtoToJson(this);
}
