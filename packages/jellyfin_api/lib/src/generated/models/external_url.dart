// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'external_url.g.dart';

@JsonSerializable()
class ExternalUrl {
  const ExternalUrl({
    this.name,
    this.url,
  });
  
  factory ExternalUrl.fromJson(Map<String, Object?> json) => _$ExternalUrlFromJson(json);
  
  /// Gets or sets the name.
  @JsonKey(name: 'Name')
  final String? name;

  /// Gets or sets the type of the item.
  @JsonKey(name: 'Url')
  final String? url;

  Map<String, Object?> toJson() => _$ExternalUrlToJson(this);
}
