// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'font_file.g.dart';

/// Class FontFile.
@JsonSerializable()
class FontFile {
  const FontFile({
    this.name,
    this.size,
    this.dateCreated,
    this.dateModified,
  });
  
  factory FontFile.fromJson(Map<String, Object?> json) => _$FontFileFromJson(json);
  
  /// Gets or sets the name.
  @JsonKey(name: 'Name')
  final String? name;

  /// Gets or sets the size.
  @JsonKey(name: 'Size')
  final int? size;

  /// Gets or sets the date created.
  @JsonKey(name: 'DateCreated')
  final DateTime? dateCreated;

  /// Gets or sets the date modified.
  @JsonKey(name: 'DateModified')
  final DateTime? dateModified;

  Map<String, Object?> toJson() => _$FontFileToJson(this);
}
