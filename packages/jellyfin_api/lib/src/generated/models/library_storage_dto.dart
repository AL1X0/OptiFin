// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'folder_storage_dto.dart';

part 'library_storage_dto.g.dart';

/// Contains informations about a libraries storage informations.
@JsonSerializable()
class LibraryStorageDto {
  const LibraryStorageDto({
    this.id,
    this.name,
    this.folders,
  });
  
  factory LibraryStorageDto.fromJson(Map<String, Object?> json) => _$LibraryStorageDtoFromJson(json);
  
  /// Gets or sets the Library Id.
  @JsonKey(name: 'Id')
  final String? id;

  /// Gets or sets the name of the library.
  @JsonKey(name: 'Name')
  final String? name;

  /// Gets or sets the storage informations about the folders used in a library.
  @JsonKey(name: 'Folders')
  final List<FolderStorageDto>? folders;

  Map<String, Object?> toJson() => _$LibraryStorageDtoToJson(this);
}
