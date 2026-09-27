// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'collection_creation_result.g.dart';

@JsonSerializable()
class CollectionCreationResult {
  const CollectionCreationResult({
    this.id,
  });
  
  factory CollectionCreationResult.fromJson(Map<String, Object?> json) => _$CollectionCreationResultFromJson(json);
  
  @JsonKey(name: 'Id')
  final String? id;

  Map<String, Object?> toJson() => _$CollectionCreationResultToJson(this);
}
