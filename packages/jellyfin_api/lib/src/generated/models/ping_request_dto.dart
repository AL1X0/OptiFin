// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'ping_request_dto.g.dart';

/// Class PingRequestDto.
@JsonSerializable()
class PingRequestDto {
  const PingRequestDto({
    this.ping,
  });
  
  factory PingRequestDto.fromJson(Map<String, Object?> json) => _$PingRequestDtoFromJson(json);
  
  /// Gets or sets the ping time.
  @JsonKey(name: 'Ping')
  final int? ping;

  Map<String, Object?> toJson() => _$PingRequestDtoToJson(this);
}
