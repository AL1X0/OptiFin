// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_log_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActivityLogEntry _$ActivityLogEntryFromJson(Map<String, dynamic> json) =>
    ActivityLogEntry(
      id: (json['Id'] as num).toInt(),
      name: json['Name'] as String?,
      overview: json['Overview'] as String?,
      shortOverview: json['ShortOverview'] as String?,
      type: json['Type'] as String?,
      itemId: json['ItemId'] as String?,
      date: json['Date'] == null
          ? null
          : DateTime.parse(json['Date'] as String),
      userId: json['UserId'] as String?,
      userPrimaryImageTag: json['UserPrimaryImageTag'] as String?,
      severity: json['Severity'] == null
          ? null
          : ActivityLogEntrySeverity.fromJson(json['Severity']),
    );

Map<String, dynamic> _$ActivityLogEntryToJson(ActivityLogEntry instance) =>
    <String, dynamic>{
      'Id': instance.id,
      'Name': instance.name,
      'Overview': instance.overview,
      'ShortOverview': instance.shortOverview,
      'Type': instance.type,
      'ItemId': instance.itemId,
      'Date': instance.date?.toIso8601String(),
      'UserId': instance.userId,
      'UserPrimaryImageTag': instance.userPrimaryImageTag,
      'Severity': instance.severity,
    };
