// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'path_substitution.g.dart';

/// Defines the MediaBrowser.Model.Configuration.PathSubstitution.
@JsonSerializable()
class PathSubstitution {
  const PathSubstitution({
    this.from,
    this.to,
  });
  
  factory PathSubstitution.fromJson(Map<String, Object?> json) => _$PathSubstitutionFromJson(json);
  
  /// Gets or sets the value to substitute.
  @JsonKey(name: 'From')
  final String? from;

  /// Gets or sets the value to substitution with.
  @JsonKey(name: 'To')
  final String? to;

  Map<String, Object?> toJson() => _$PathSubstitutionToJson(this);
}
