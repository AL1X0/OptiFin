// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MessageCommand _$MessageCommandFromJson(Map<String, dynamic> json) =>
    MessageCommand(
      text: json['Text'] as String,
      header: json['Header'] as String?,
      timeoutMs: (json['TimeoutMs'] as num?)?.toInt(),
    );

Map<String, dynamic> _$MessageCommandToJson(MessageCommand instance) =>
    <String, dynamic>{
      'Header': instance.header,
      'Text': instance.text,
      'TimeoutMs': instance.timeoutMs,
    };
