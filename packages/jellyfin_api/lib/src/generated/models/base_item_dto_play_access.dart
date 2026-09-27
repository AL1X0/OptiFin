// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

/// Gets or sets the play access.
@JsonEnum()
enum BaseItemDtoPlayAccess {
  @JsonValue('Full')
  full('Full'),
  @JsonValue('None')
  none('None'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const BaseItemDtoPlayAccess(this.json);

  factory BaseItemDtoPlayAccess.fromJson(dynamic json) => values.firstWhere(
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
  static List<BaseItemDtoPlayAccess> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
