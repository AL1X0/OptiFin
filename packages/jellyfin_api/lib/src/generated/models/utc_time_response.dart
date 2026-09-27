// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'utc_time_response.g.dart';

/// Class UtcTimeResponse.
@JsonSerializable()
class UtcTimeResponse {
  const UtcTimeResponse({
    this.requestReceptionTime,
    this.responseTransmissionTime,
  });
  
  factory UtcTimeResponse.fromJson(Map<String, Object?> json) => _$UtcTimeResponseFromJson(json);
  
  /// Gets the UTC time when request has been received.
  @JsonKey(name: 'RequestReceptionTime')
  final DateTime? requestReceptionTime;

  /// Gets the UTC time when response has been sent.
  @JsonKey(name: 'ResponseTransmissionTime')
  final DateTime? responseTransmissionTime;

  Map<String, Object?> toJson() => _$UtcTimeResponseToJson(this);
}
