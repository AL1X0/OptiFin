// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum ProcessPriorityClass {
  @JsonValue('Normal')
  normal('Normal'),
  @JsonValue('Idle')
  idle('Idle'),
  @JsonValue('High')
  high('High'),
  @JsonValue('RealTime')
  realTime('RealTime'),
  @JsonValue('BelowNormal')
  belowNormal('BelowNormal'),
  @JsonValue('AboveNormal')
  aboveNormal('AboveNormal'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const ProcessPriorityClass(this.json);

  factory ProcessPriorityClass.fromJson(String json) => values.firstWhere(
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
  static List<ProcessPriorityClass> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
