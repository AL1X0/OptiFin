// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'general_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GeneralCommand _$GeneralCommandFromJson(Map<String, dynamic> json) =>
    GeneralCommand(
      name: json['Name'] == null
          ? null
          : GeneralCommandName.fromJson(json['Name']),
      controllingUserId: json['ControllingUserId'] as String?,
      arguments: (json['Arguments'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
    );

Map<String, dynamic> _$GeneralCommandToJson(GeneralCommand instance) =>
    <String, dynamic>{
      'Name': instance.name,
      'ControllingUserId': instance.controllingUserId,
      'Arguments': instance.arguments,
    };
