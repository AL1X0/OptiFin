// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

/// Gets or sets the type of the collection.
@JsonEnum()
enum BaseItemDtoCollectionType {
  @JsonValue('unknown')
  unknown('unknown'),
  @JsonValue('movies')
  movies('movies'),
  @JsonValue('tvshows')
  tvshows('tvshows'),
  @JsonValue('music')
  music('music'),
  @JsonValue('musicvideos')
  musicvideos('musicvideos'),
  @JsonValue('trailers')
  trailers('trailers'),
  @JsonValue('homevideos')
  homevideos('homevideos'),
  @JsonValue('boxsets')
  boxsets('boxsets'),
  @JsonValue('books')
  books('books'),
  @JsonValue('photos')
  photos('photos'),
  @JsonValue('livetv')
  livetv('livetv'),
  @JsonValue('playlists')
  playlists('playlists'),
  @JsonValue('folders')
  folders('folders'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const BaseItemDtoCollectionType(this.json);

  factory BaseItemDtoCollectionType.fromJson(dynamic json) => values.firstWhere(
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
  static List<BaseItemDtoCollectionType> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
