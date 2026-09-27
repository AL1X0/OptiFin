// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'media_url.g.dart';

@JsonSerializable()
class MediaUrl {
  const MediaUrl({
    this.url,
    this.name,
  });
  
  factory MediaUrl.fromJson(Map<String, Object?> json) => _$MediaUrlFromJson(json);
  
  @JsonKey(name: 'Url')
  final String? url;
  @JsonKey(name: 'Name')
  final String? name;

  Map<String, Object?> toJson() => _$MediaUrlToJson(this);
}
