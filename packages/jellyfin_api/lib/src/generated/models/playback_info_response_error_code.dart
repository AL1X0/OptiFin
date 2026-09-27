// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

/// Gets or sets the error code.
@JsonEnum()
enum PlaybackInfoResponseErrorCode {
  @JsonValue('NotAllowed')
  notAllowed('NotAllowed'),
  @JsonValue('NoCompatibleStream')
  noCompatibleStream('NoCompatibleStream'),
  @JsonValue('RateLimitExceeded')
  rateLimitExceeded('RateLimitExceeded'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const PlaybackInfoResponseErrorCode(this.json);

  factory PlaybackInfoResponseErrorCode.fromJson(dynamic json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final dynamic json;
  dynamic toJson() {
    final value = json;
    if (value == null) {
      throw StateError('Cannot convert enum value with null JSON representation to dynamic. '
          'This usually happens for \$unknown or @JsonValue(null) entries.');
    }
    return value as dynamic;
  }

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<PlaybackInfoResponseErrorCode> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
