// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

/// Activity log sorting options.
@JsonEnum()
enum ActivityLogSortBy {
  @JsonValue('Name')
  name('Name'),
  @JsonValue('Overiew')
  overiew('Overiew'),
  @JsonValue('ShortOverview')
  shortOverview('ShortOverview'),
  @JsonValue('Type')
  type('Type'),
  @JsonValue('DateCreated')
  dateCreated('DateCreated'),
  @JsonValue('Username')
  username('Username'),
  @JsonValue('LogSeverity')
  logSeverity('LogSeverity'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const ActivityLogSortBy(this.json);

  factory ActivityLogSortBy.fromJson(String json) => values.firstWhere(
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
  static List<ActivityLogSortBy> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
