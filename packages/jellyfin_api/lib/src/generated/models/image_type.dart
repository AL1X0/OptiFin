// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

/// Enum ImageType.
@JsonEnum()
enum ImageType {
  @JsonValue('Primary')
  primary('Primary'),
  @JsonValue('Art')
  art('Art'),
  @JsonValue('Backdrop')
  backdrop('Backdrop'),
  @JsonValue('Banner')
  banner('Banner'),
  @JsonValue('Logo')
  logo('Logo'),
  @JsonValue('Thumb')
  thumb('Thumb'),
  @JsonValue('Disc')
  disc('Disc'),
  @JsonValue('Box')
  box('Box'),
  @JsonValue('Screenshot')
  screenshot('Screenshot'),
  @JsonValue('Menu')
  menu('Menu'),
  @JsonValue('Chapter')
  chapter('Chapter'),
  @JsonValue('BoxRear')
  boxRear('BoxRear'),
  @JsonValue('Profile')
  profile('Profile'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const ImageType(this.json);

  factory ImageType.fromJson(String json) => values.firstWhere(
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
  static List<ImageType> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
