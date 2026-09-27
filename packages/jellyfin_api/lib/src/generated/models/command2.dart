// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

/// Enum PlaystateCommand.
@JsonEnum()
enum Command2 {
  @JsonValue('Stop')
  stop('Stop'),
  @JsonValue('Pause')
  pause('Pause'),
  @JsonValue('Unpause')
  unpause('Unpause'),
  @JsonValue('NextTrack')
  nextTrack('NextTrack'),
  @JsonValue('PreviousTrack')
  previousTrack('PreviousTrack'),
  @JsonValue('Seek')
  seek('Seek'),
  @JsonValue('Rewind')
  rewind('Rewind'),
  @JsonValue('FastForward')
  fastForward('FastForward'),
  @JsonValue('PlayPause')
  playPause('PlayPause'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const Command2(this.json);

  factory Command2.fromJson(dynamic json) => values.firstWhere(
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
  static List<Command2> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
