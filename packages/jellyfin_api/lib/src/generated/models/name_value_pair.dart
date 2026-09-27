// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'name_value_pair.g.dart';

@JsonSerializable()
class NameValuePair {
  const NameValuePair({
    this.name,
    this.value,
  });
  
  factory NameValuePair.fromJson(Map<String, Object?> json) => _$NameValuePairFromJson(json);
  
  /// Gets or sets the name.
  @JsonKey(name: 'Name')
  final String? name;

  /// Gets or sets the value.
  @JsonKey(name: 'Value')
  final String? value;

  Map<String, Object?> toJson() => _$NameValuePairToJson(this);
}
