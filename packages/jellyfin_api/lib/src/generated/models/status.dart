// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum Status {
  /// The name has been replaced because it contains a keyword. Original name: `New`.
  @JsonValue('New')
  valueNew('New'),
  @JsonValue('InProgress')
  inProgress('InProgress'),
  @JsonValue('Completed')
  completed('Completed'),
  @JsonValue('Cancelled')
  cancelled('Cancelled'),
  @JsonValue('ConflictedOk')
  conflictedOk('ConflictedOk'),
  @JsonValue('ConflictedNotOk')
  conflictedNotOk('ConflictedNotOk'),
  @JsonValue('Error')
  error('Error'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const Status(this.json);

  factory Status.fromJson(dynamic json) => values.firstWhere(
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
  static List<Status> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
