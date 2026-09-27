// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'name_id_pair.g.dart';

@JsonSerializable()
class NameIdPair {
  const NameIdPair({
    this.name,
    this.id,
  });
  
  factory NameIdPair.fromJson(Map<String, Object?> json) => _$NameIdPairFromJson(json);
  
  /// Gets or sets the name.
  @JsonKey(name: 'Name')
  final String? name;

  /// Gets or sets the identifier.
  @JsonKey(name: 'Id')
  final String? id;

  Map<String, Object?> toJson() => _$NameIdPairToJson(this);
}
