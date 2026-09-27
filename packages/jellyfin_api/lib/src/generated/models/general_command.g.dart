// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'general_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GeneralCommand _$GeneralCommandFromJson(Map<String, dynamic> json) =>
    GeneralCommand(
      name: GeneralCommandName.fromJson(json['Name']),
      controllingUserId: json['ControllingUserId'] as String,
      arguments: Map<String, String>.from(json['Arguments'] as Map),
    );

Map<String, dynamic> _$GeneralCommandToJson(GeneralCommand instance) =>
    <String, dynamic>{
      'Name': instance.name,
      'ControllingUserId': instance.controllingUserId,
      'Arguments': instance.arguments,
    };
