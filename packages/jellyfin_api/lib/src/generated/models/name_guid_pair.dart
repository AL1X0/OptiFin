// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'name_guid_pair.g.dart';

@JsonSerializable()
class NameGuidPair {
  const NameGuidPair({
    this.name,
    this.id,
  });
  
  factory NameGuidPair.fromJson(Map<String, Object?> json) => _$NameGuidPairFromJson(json);
  
  @JsonKey(name: 'Name')
  final String? name;
  @JsonKey(name: 'Id')
  final String? id;

  Map<String, Object?> toJson() => _$NameGuidPairToJson(this);
}
