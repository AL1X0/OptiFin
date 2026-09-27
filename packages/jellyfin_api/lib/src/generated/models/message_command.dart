// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'message_command.g.dart';

/// A command to display a message on a client.
@JsonSerializable()
class MessageCommand {
  const MessageCommand({
    this.header,
    this.text,
    this.timeoutMs,
  });
  
  factory MessageCommand.fromJson(Map<String, Object?> json) => _$MessageCommandFromJson(json);
  
  /// Gets or sets the message header.
  @JsonKey(name: 'Header')
  final String? header;

  /// Gets or sets the message text.
  @JsonKey(name: 'Text')
  final String? text;

  /// Gets or sets the timeout in milliseconds after which the message should be dismissed.
  @JsonKey(name: 'TimeoutMs')
  final int? timeoutMs;

  Map<String, Object?> toJson() => _$MessageCommandToJson(this);
}
