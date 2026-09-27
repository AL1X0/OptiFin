// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

/// An enum that represents a day of the week, weekdays, weekends, or all days.
@JsonEnum()
enum DynamicDayOfWeek {
  @JsonValue('Sunday')
  sunday('Sunday'),
  @JsonValue('Monday')
  monday('Monday'),
  @JsonValue('Tuesday')
  tuesday('Tuesday'),
  @JsonValue('Wednesday')
  wednesday('Wednesday'),
  @JsonValue('Thursday')
  thursday('Thursday'),
  @JsonValue('Friday')
  friday('Friday'),
  @JsonValue('Saturday')
  saturday('Saturday'),
  @JsonValue('Everyday')
  everyday('Everyday'),
  @JsonValue('Weekday')
  weekday('Weekday'),
  @JsonValue('Weekend')
  weekend('Weekend'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const DynamicDayOfWeek(this.json);

  factory DynamicDayOfWeek.fromJson(String json) => values.firstWhere(
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
  static List<DynamicDayOfWeek> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
