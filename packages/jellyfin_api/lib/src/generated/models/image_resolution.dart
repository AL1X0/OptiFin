// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

/// Enum ImageResolution.
@JsonEnum()
enum ImageResolution {
  @JsonValue('MatchSource')
  matchSource('MatchSource'),
  @JsonValue('P144')
  p144('P144'),
  @JsonValue('P240')
  p240('P240'),
  @JsonValue('P360')
  p360('P360'),
  @JsonValue('P480')
  p480('P480'),
  @JsonValue('P720')
  p720('P720'),
  @JsonValue('P1080')
  p1080('P1080'),
  @JsonValue('P1440')
  p1440('P1440'),
  @JsonValue('P2160')
  p2160('P2160'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const ImageResolution(this.json);

  factory ImageResolution.fromJson(String json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final String? json;
  String toJson() {
    final value = json;
    if (value == null) {
      throw StateError('Cannot convert enum value with null JSON representation to String. '
          'This usually happens for \$unknown or @JsonValue(null) entries.');
    }
    return value as String;
  }

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<ImageResolution> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
