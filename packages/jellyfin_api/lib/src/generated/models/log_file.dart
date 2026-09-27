// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'log_file.g.dart';

@JsonSerializable()
class LogFile {
  const LogFile({
    this.dateCreated,
    this.dateModified,
    this.size,
    this.name,
  });
  
  factory LogFile.fromJson(Map<String, Object?> json) => _$LogFileFromJson(json);
  
  /// Gets or sets the date created.
  @JsonKey(name: 'DateCreated')
  final DateTime? dateCreated;

  /// Gets or sets the date modified.
  @JsonKey(name: 'DateModified')
  final DateTime? dateModified;

  /// Gets or sets the size.
  @JsonKey(name: 'Size')
  final int? size;

  /// Gets or sets the name.
  @JsonKey(name: 'Name')
  final String? name;

  Map<String, Object?> toJson() => _$LogFileToJson(this);
}
