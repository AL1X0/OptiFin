// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

/// An enum representing the axis that should be scrolled.
@JsonEnum()
enum DisplayPreferencesDtoScrollDirection {
  @JsonValue('Horizontal')
  horizontal('Horizontal'),
  @JsonValue('Vertical')
  vertical('Vertical'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const DisplayPreferencesDtoScrollDirection(this.json);

  factory DisplayPreferencesDtoScrollDirection.fromJson(dynamic json) => values.firstWhere(
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
  static List<DisplayPreferencesDtoScrollDirection> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
