// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'series_timer_info_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SeriesTimerInfoDto _$SeriesTimerInfoDtoFromJson(Map<String, dynamic> json) =>
    SeriesTimerInfoDto(
      startDate: json['StartDate'] == null
          ? null
          : DateTime.parse(json['StartDate'] as String),
      type: json['Type'] as String?,
      serverId: json['ServerId'] as String?,
      externalId: json['ExternalId'] as String?,
      channelId: json['ChannelId'] as String?,
      externalChannelId: json['ExternalChannelId'] as String?,
      channelName: json['ChannelName'] as String?,
      channelPrimaryImageTag: json['ChannelPrimaryImageTag'] as String?,
      programId: json['ProgramId'] as String?,
      externalProgramId: json['ExternalProgramId'] as String?,
      name: json['Name'] as String?,
      overview: json['Overview'] as String?,
      id: json['Id'] as String?,
      endDate: json['EndDate'] == null
          ? null
          : DateTime.parse(json['EndDate'] as String),
      serviceName: json['ServiceName'] as String?,
      priority: (json['Priority'] as num?)?.toInt(),
      prePaddingSeconds: (json['PrePaddingSeconds'] as num?)?.toInt(),
      postPaddingSeconds: (json['PostPaddingSeconds'] as num?)?.toInt(),
      isPrePaddingRequired: json['IsPrePaddingRequired'] as bool?,
      parentBackdropItemId: json['ParentBackdropItemId'] as String?,
      parentBackdropImageTags:
          (json['ParentBackdropImageTags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      isPostPaddingRequired: json['IsPostPaddingRequired'] as bool?,
      parentPrimaryImageTag: json['ParentPrimaryImageTag'] as String?,
      recordAnyTime: json['RecordAnyTime'] as bool?,
      skipEpisodesInLibrary: json['SkipEpisodesInLibrary'] as bool?,
      recordAnyChannel: json['RecordAnyChannel'] as bool?,
      keepUpTo: (json['KeepUpTo'] as num?)?.toInt(),
      recordNewOnly: json['RecordNewOnly'] as bool?,
      days: (json['Days'] as List<dynamic>?)
          ?.map((e) => DayOfWeek.fromJson(e as String))
          .toList(),
      dayPattern: json['DayPattern'] == null
          ? null
          : SeriesTimerInfoDtoDayPattern.fromJson(json['DayPattern']),
      imageTags: (json['ImageTags'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String?),
      ),
      parentThumbItemId: json['ParentThumbItemId'] as String?,
      parentThumbImageTag: json['ParentThumbImageTag'] as String?,
      parentPrimaryImageItemId: json['ParentPrimaryImageItemId'] as String?,
      keepUntil: json['KeepUntil'] == null
          ? null
          : SeriesTimerInfoDtoKeepUntil.fromJson(json['KeepUntil']),
    );

Map<String, dynamic> _$SeriesTimerInfoDtoToJson(SeriesTimerInfoDto instance) =>
    <String, dynamic>{
      'Id': instance.id,
      'Type': instance.type,
      'ServerId': instance.serverId,
      'ExternalId': instance.externalId,
      'ChannelId': instance.channelId,
      'ExternalChannelId': instance.externalChannelId,
      'ChannelName': instance.channelName,
      'ChannelPrimaryImageTag': instance.channelPrimaryImageTag,
      'ProgramId': instance.programId,
      'ExternalProgramId': instance.externalProgramId,
      'Name': instance.name,
      'Overview': instance.overview,
      'StartDate': instance.startDate?.toIso8601String(),
      'EndDate': instance.endDate?.toIso8601String(),
      'ServiceName': instance.serviceName,
      'Priority': instance.priority,
      'PrePaddingSeconds': instance.prePaddingSeconds,
      'PostPaddingSeconds': instance.postPaddingSeconds,
      'IsPrePaddingRequired': instance.isPrePaddingRequired,
      'ParentBackdropItemId': instance.parentBackdropItemId,
      'ParentBackdropImageTags': instance.parentBackdropImageTags,
      'IsPostPaddingRequired': instance.isPostPaddingRequired,
      'KeepUntil': instance.keepUntil,
      'RecordAnyTime': instance.recordAnyTime,
      'SkipEpisodesInLibrary': instance.skipEpisodesInLibrary,
      'RecordAnyChannel': instance.recordAnyChannel,
      'KeepUpTo': instance.keepUpTo,
      'RecordNewOnly': instance.recordNewOnly,
      'Days': instance.days,
      'DayPattern': instance.dayPattern,
      'ImageTags': instance.imageTags,
      'ParentThumbItemId': instance.parentThumbItemId,
      'ParentThumbImageTag': instance.parentThumbImageTag,
      'ParentPrimaryImageItemId': instance.parentPrimaryImageItemId,
      'ParentPrimaryImageTag': instance.parentPrimaryImageTag,
    };
