// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

/// Enum PlaybackOrder.
@JsonEnum()
enum PlaybackOrder {
  /// The name has been replaced because it contains a keyword. Original name: `Default`.
  @JsonValue('Default')
  valueDefault('Default'),
  @JsonValue('Shuffle')
  shuffle('Shuffle'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const PlaybackOrder(this.json);

  factory PlaybackOrder.fromJson(String json) => values.firstWhere(
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
  static List<PlaybackOrder> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
