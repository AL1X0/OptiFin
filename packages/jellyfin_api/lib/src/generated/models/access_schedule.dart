// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'access_schedule_day_of_week.dart';

part 'access_schedule.g.dart';

/// An entity representing a user's access schedule.
@JsonSerializable()
class AccessSchedule {
  const AccessSchedule({
    required this.id,
    required this.userId,
    required this.dayOfWeek,
    required this.startHour,
    required this.endHour,
  });
  
  factory AccessSchedule.fromJson(Map<String, Object?> json) => _$AccessScheduleFromJson(json);
  
  /// Gets the id of this instance.
  @JsonKey(name: 'Id')
  final int id;

  /// Gets the id of the associated user.
  @JsonKey(name: 'UserId')
  final String? userId;

  /// Gets or sets the day of week.
  @JsonKey(name: 'DayOfWeek')
  final AccessScheduleDayOfWeek? dayOfWeek;

  /// Gets or sets the start hour.
  @JsonKey(name: 'StartHour')
  final double? startHour;

  /// Gets or sets the end hour.
  @JsonKey(name: 'EndHour')
  final double? endHour;

  Map<String, Object?> toJson() => _$AccessScheduleToJson(this);
}
