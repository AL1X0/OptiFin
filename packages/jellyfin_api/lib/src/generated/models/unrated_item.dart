// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

/// An enum representing an unrated item.
@JsonEnum()
enum UnratedItem {
  @JsonValue('Movie')
  movie('Movie'),
  @JsonValue('Trailer')
  trailer('Trailer'),
  @JsonValue('Series')
  series('Series'),
  @JsonValue('Music')
  music('Music'),
  @JsonValue('Book')
  book('Book'),
  @JsonValue('LiveTvChannel')
  liveTvChannel('LiveTvChannel'),
  @JsonValue('LiveTvProgram')
  liveTvProgram('LiveTvProgram'),
  @JsonValue('ChannelContent')
  channelContent('ChannelContent'),
  @JsonValue('Other')
  other('Other'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const UnratedItem(this.json);

  factory UnratedItem.fromJson(String json) => values.firstWhere(
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
  static List<UnratedItem> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
