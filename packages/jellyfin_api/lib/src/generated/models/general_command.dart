// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'general_command_name.dart';

part 'general_command.g.dart';

@JsonSerializable()
class GeneralCommand {
  const GeneralCommand({
    required this.name,
    required this.controllingUserId,
    required this.arguments,
  });
  
  factory GeneralCommand.fromJson(Map<String, Object?> json) => _$GeneralCommandFromJson(json);
  
  /// This exists simply to identify a set of known commands.
  @JsonKey(name: 'Name')
  final GeneralCommandName? name;
  @JsonKey(name: 'ControllingUserId')
  final String? controllingUserId;
  @JsonKey(name: 'Arguments')
  final Map<String, String>? arguments;

  Map<String, Object?> toJson() => _$GeneralCommandToJson(this);
}
