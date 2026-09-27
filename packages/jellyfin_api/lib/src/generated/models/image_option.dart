// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'image_option_type.dart';

part 'image_option.g.dart';

@JsonSerializable()
class ImageOption {
  const ImageOption({
    required this.type,
    required this.limit,
    required this.minWidth,
  });
  
  factory ImageOption.fromJson(Map<String, Object?> json) => _$ImageOptionFromJson(json);
  
  /// Gets or sets the type.
  @JsonKey(name: 'Type')
  final ImageOptionType? type;

  /// Gets or sets the limit.
  @JsonKey(name: 'Limit')
  final int? limit;

  /// Gets or sets the minimum width.
  @JsonKey(name: 'MinWidth')
  final int? minWidth;

  Map<String, Object?> toJson() => _$ImageOptionToJson(this);
}
