// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'cast_receiver_application.g.dart';

/// The cast receiver application model.
@JsonSerializable()
class CastReceiverApplication {
  const CastReceiverApplication({
    required this.id,
    required this.name,
  });
  
  factory CastReceiverApplication.fromJson(Map<String, Object?> json) => _$CastReceiverApplicationFromJson(json);
  
  /// Gets or sets the cast receiver application id.
  @JsonKey(name: 'Id')
  final String id;

  /// Gets or sets the cast receiver application name.
  @JsonKey(name: 'Name')
  final String name;

  Map<String, Object?> toJson() => _$CastReceiverApplicationToJson(this);
}
