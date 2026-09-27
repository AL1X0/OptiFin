// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'activity_log_entry_severity.dart';

part 'activity_log_entry.g.dart';

/// An activity log entry.
@JsonSerializable()
class ActivityLogEntry {
  const ActivityLogEntry({
    required this.id,
    required this.name,
    required this.overview,
    required this.shortOverview,
    required this.type,
    required this.itemId,
    required this.date,
    required this.userId,
    required this.userPrimaryImageTag,
    required this.severity,
  });
  
  factory ActivityLogEntry.fromJson(Map<String, Object?> json) => _$ActivityLogEntryFromJson(json);
  
  /// Gets or sets the identifier.
  @JsonKey(name: 'Id')
  final int id;

  /// Gets or sets the name.
  @JsonKey(name: 'Name')
  final String? name;

  /// Gets or sets the overview.
  @JsonKey(name: 'Overview')
  final String? overview;

  /// Gets or sets the short overview.
  @JsonKey(name: 'ShortOverview')
  final String? shortOverview;

  /// Gets or sets the type.
  @JsonKey(name: 'Type')
  final String? type;

  /// Gets or sets the item identifier.
  @JsonKey(name: 'ItemId')
  final String? itemId;

  /// Gets or sets the date.
  @JsonKey(name: 'Date')
  final DateTime? date;

  /// Gets or sets the user identifier.
  @JsonKey(name: 'UserId')
  final String? userId;

  /// Gets or sets the user primary image tag.
  @JsonKey(name: 'UserPrimaryImageTag')
  final String? userPrimaryImageTag;

  /// Gets or sets the log severity.
  @JsonKey(name: 'Severity')
  final ActivityLogEntrySeverity? severity;

  Map<String, Object?> toJson() => _$ActivityLogEntryToJson(this);
}
