// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'day_of_week.dart';
import 'series_timer_info_dto_day_pattern.dart';
import 'series_timer_info_dto_keep_until.dart';

part 'series_timer_info_dto.g.dart';

/// Class SeriesTimerInfoDto.
@JsonSerializable()
class SeriesTimerInfoDto {
  const SeriesTimerInfoDto({
    required this.startDate,
    required this.type,
    required this.serverId,
    required this.externalId,
    required this.channelId,
    required this.externalChannelId,
    required this.channelName,
    required this.channelPrimaryImageTag,
    required this.programId,
    required this.externalProgramId,
    required this.name,
    required this.overview,
    required this.id,
    required this.endDate,
    required this.serviceName,
    required this.priority,
    required this.prePaddingSeconds,
    required this.postPaddingSeconds,
    required this.isPrePaddingRequired,
    required this.parentBackdropItemId,
    required this.parentBackdropImageTags,
    required this.isPostPaddingRequired,
    required this.parentPrimaryImageTag,
    required this.recordAnyTime,
    required this.skipEpisodesInLibrary,
    required this.recordAnyChannel,
    required this.keepUpTo,
    required this.recordNewOnly,
    required this.days,
    required this.dayPattern,
    required this.imageTags,
    required this.parentThumbItemId,
    required this.parentThumbImageTag,
    required this.parentPrimaryImageItemId,
    required this.keepUntil,
  });
  
  factory SeriesTimerInfoDto.fromJson(Map<String, Object?> json) => _$SeriesTimerInfoDtoFromJson(json);
  
  /// Gets or sets the Id of the recording.
  @JsonKey(name: 'Id')
  final String? id;
  @JsonKey(name: 'Type')
  final String? type;

  /// Gets or sets the server identifier.
  @JsonKey(name: 'ServerId')
  final String? serverId;

  /// Gets or sets the external identifier.
  @JsonKey(name: 'ExternalId')
  final String? externalId;

  /// Gets or sets the channel id of the recording.
  @JsonKey(name: 'ChannelId')
  final String channelId;

  /// Gets or sets the external channel identifier.
  @JsonKey(name: 'ExternalChannelId')
  final String? externalChannelId;

  /// Gets or sets the channel name of the recording.
  @JsonKey(name: 'ChannelName')
  final String? channelName;
  @JsonKey(name: 'ChannelPrimaryImageTag')
  final String? channelPrimaryImageTag;

  /// Gets or sets the program identifier.
  @JsonKey(name: 'ProgramId')
  final String? programId;

  /// Gets or sets the external program identifier.
  @JsonKey(name: 'ExternalProgramId')
  final String? externalProgramId;

  /// Gets or sets the name of the recording.
  @JsonKey(name: 'Name')
  final String? name;

  /// Gets or sets the description of the recording.
  @JsonKey(name: 'Overview')
  final String? overview;

  /// Gets or sets the start date of the recording, in UTC.
  @JsonKey(name: 'StartDate')
  final DateTime startDate;

  /// Gets or sets the end date of the recording, in UTC.
  @JsonKey(name: 'EndDate')
  final DateTime endDate;

  /// Gets or sets the name of the service.
  @JsonKey(name: 'ServiceName')
  final String? serviceName;

  /// Gets or sets the priority.
  @JsonKey(name: 'Priority')
  final int priority;

  /// Gets or sets the pre padding seconds.
  @JsonKey(name: 'PrePaddingSeconds')
  final int prePaddingSeconds;

  /// Gets or sets the post padding seconds.
  @JsonKey(name: 'PostPaddingSeconds')
  final int postPaddingSeconds;

  /// Gets or sets a value indicating whether this instance is pre padding required.
  @JsonKey(name: 'IsPrePaddingRequired')
  final bool isPrePaddingRequired;

  /// Gets or sets the Id of the Parent that has a backdrop if the item does not have one.
  @JsonKey(name: 'ParentBackdropItemId')
  final String? parentBackdropItemId;

  /// Gets or sets the parent backdrop image tags.
  @JsonKey(name: 'ParentBackdropImageTags')
  final List<String>? parentBackdropImageTags;

  /// Gets or sets a value indicating whether this instance is post padding required.
  @JsonKey(name: 'IsPostPaddingRequired')
  final bool isPostPaddingRequired;
  @JsonKey(name: 'KeepUntil')
  final SeriesTimerInfoDtoKeepUntil keepUntil;

  /// Gets or sets a value indicating whether [record any time].
  @JsonKey(name: 'RecordAnyTime')
  final bool recordAnyTime;
  @JsonKey(name: 'SkipEpisodesInLibrary')
  final bool skipEpisodesInLibrary;

  /// Gets or sets a value indicating whether [record any channel].
  @JsonKey(name: 'RecordAnyChannel')
  final bool recordAnyChannel;
  @JsonKey(name: 'KeepUpTo')
  final int keepUpTo;

  /// Gets or sets a value indicating whether [record new only].
  @JsonKey(name: 'RecordNewOnly')
  final bool recordNewOnly;

  /// Gets or sets the days.
  @JsonKey(name: 'Days')
  final List<DayOfWeek>? days;

  /// Gets or sets the day pattern.
  @JsonKey(name: 'DayPattern')
  final SeriesTimerInfoDtoDayPattern? dayPattern;

  /// Gets or sets the image tags.
  @JsonKey(name: 'ImageTags')
  final Map<String, String?>? imageTags;

  /// Gets or sets the parent thumb item id.
  @JsonKey(name: 'ParentThumbItemId')
  final String? parentThumbItemId;

  /// Gets or sets the parent thumb image tag.
  @JsonKey(name: 'ParentThumbImageTag')
  final String? parentThumbImageTag;

  /// Gets or sets the parent primary image item identifier.
  @JsonKey(name: 'ParentPrimaryImageItemId')
  final String? parentPrimaryImageItemId;

  /// Gets or sets the parent primary image tag.
  @JsonKey(name: 'ParentPrimaryImageTag')
  final String? parentPrimaryImageTag;

  Map<String, Object?> toJson() => _$SeriesTimerInfoDtoToJson(this);
}
