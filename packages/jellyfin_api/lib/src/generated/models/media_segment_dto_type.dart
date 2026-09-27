// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

/// Defines the types of content an individual Jellyfin.Database.Implementations.Entities.MediaSegment represents.
@JsonEnum()
enum MediaSegmentDtoType {
  @JsonValue('Unknown')
  unknown('Unknown'),
  @JsonValue('Commercial')
  commercial('Commercial'),
  @JsonValue('Preview')
  preview('Preview'),
  @JsonValue('Recap')
  recap('Recap'),
  @JsonValue('Outro')
  outro('Outro'),
  @JsonValue('Intro')
  intro('Intro'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const MediaSegmentDtoType(this.json);

  factory MediaSegmentDtoType.fromJson(dynamic json) => values.firstWhere(
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
  static List<MediaSegmentDtoType> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
