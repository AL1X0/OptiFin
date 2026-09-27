// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'base_item_person_type.dart';
import 'image_blur_hashes2.dart';

part 'base_item_person.g.dart';

/// This is used by the api to get information about a Person within a BaseItem.
@JsonSerializable()
class BaseItemPerson {
  const BaseItemPerson({
    required this.name,
    required this.id,
    required this.role,
    required this.type,
    required this.primaryImageTag,
    required this.imageBlurHashes,
  });
  
  factory BaseItemPerson.fromJson(Map<String, Object?> json) => _$BaseItemPersonFromJson(json);
  
  /// Gets or sets the name.
  @JsonKey(name: 'Name')
  final String? name;

  /// Gets or sets the identifier.
  @JsonKey(name: 'Id')
  final String id;

  /// Gets or sets the role.
  @JsonKey(name: 'Role')
  final String? role;

  /// The person kind.
  @JsonKey(name: 'Type')
  final BaseItemPersonType type;

  /// Gets or sets the primary image tag.
  @JsonKey(name: 'PrimaryImageTag')
  final String? primaryImageTag;

  /// Gets or sets the primary image blurhash.
  @JsonKey(name: 'ImageBlurHashes')
  final ImageBlurHashes2? imageBlurHashes;

  Map<String, Object?> toJson() => _$BaseItemPersonToJson(this);
}
