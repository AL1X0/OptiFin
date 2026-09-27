// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'quick_connect_dto.g.dart';

/// The quick connect request body.
@JsonSerializable()
class QuickConnectDto {
  const QuickConnectDto({
    this.secret,
  });
  
  factory QuickConnectDto.fromJson(Map<String, Object?> json) => _$QuickConnectDtoFromJson(json);
  
  /// Gets or sets the quick connect secret.
  @JsonKey(name: 'Secret')
  final String? secret;

  Map<String, Object?> toJson() => _$QuickConnectDtoToJson(this);
}
