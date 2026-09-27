// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remote_subtitle_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RemoteSubtitleInfo _$RemoteSubtitleInfoFromJson(Map<String, dynamic> json) =>
    RemoteSubtitleInfo(
      threeLetterIsoLanguageName: json['ThreeLetterISOLanguageName'] as String?,
      id: json['Id'] as String?,
      providerName: json['ProviderName'] as String?,
      name: json['Name'] as String?,
      format: json['Format'] as String?,
      author: json['Author'] as String?,
      comment: json['Comment'] as String?,
      dateCreated: json['DateCreated'] == null
          ? null
          : DateTime.parse(json['DateCreated'] as String),
      communityRating: (json['CommunityRating'] as num?)?.toDouble(),
      frameRate: (json['FrameRate'] as num?)?.toDouble(),
      downloadCount: (json['DownloadCount'] as num?)?.toInt(),
      isHashMatch: json['IsHashMatch'] as bool?,
      aiTranslated: json['AiTranslated'] as bool?,
      machineTranslated: json['MachineTranslated'] as bool?,
      forced: json['Forced'] as bool?,
      hearingImpaired: json['HearingImpaired'] as bool?,
    );

Map<String, dynamic> _$RemoteSubtitleInfoToJson(RemoteSubtitleInfo instance) =>
    <String, dynamic>{
      'ThreeLetterISOLanguageName': ?instance.threeLetterIsoLanguageName,
      'Id': ?instance.id,
      'ProviderName': ?instance.providerName,
      'Name': ?instance.name,
      'Format': ?instance.format,
      'Author': ?instance.author,
      'Comment': ?instance.comment,
      'DateCreated': ?instance.dateCreated?.toIso8601String(),
      'CommunityRating': ?instance.communityRating,
      'FrameRate': ?instance.frameRate,
      'DownloadCount': ?instance.downloadCount,
      'IsHashMatch': ?instance.isHashMatch,
      'AiTranslated': ?instance.aiTranslated,
      'MachineTranslated': ?instance.machineTranslated,
      'Forced': ?instance.forced,
      'HearingImpaired': ?instance.hearingImpaired,
    };
