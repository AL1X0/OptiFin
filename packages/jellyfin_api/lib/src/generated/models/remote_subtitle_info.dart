// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'remote_subtitle_info.g.dart';

@JsonSerializable()
class RemoteSubtitleInfo {
  const RemoteSubtitleInfo({
    this.threeLetterIsoLanguageName,
    this.id,
    this.providerName,
    this.name,
    this.format,
    this.author,
    this.comment,
    this.dateCreated,
    this.communityRating,
    this.frameRate,
    this.downloadCount,
    this.isHashMatch,
    this.aiTranslated,
    this.machineTranslated,
    this.forced,
    this.hearingImpaired,
  });
  
  factory RemoteSubtitleInfo.fromJson(Map<String, Object?> json) => _$RemoteSubtitleInfoFromJson(json);
  
  @JsonKey(name: 'ThreeLetterISOLanguageName')
  final String? threeLetterIsoLanguageName;
  @JsonKey(name: 'Id')
  final String? id;
  @JsonKey(name: 'ProviderName')
  final String? providerName;
  @JsonKey(name: 'Name')
  final String? name;
  @JsonKey(name: 'Format')
  final String? format;
  @JsonKey(name: 'Author')
  final String? author;
  @JsonKey(name: 'Comment')
  final String? comment;
  @JsonKey(name: 'DateCreated')
  final DateTime? dateCreated;
  @JsonKey(name: 'CommunityRating')
  final double? communityRating;
  @JsonKey(name: 'FrameRate')
  final double? frameRate;
  @JsonKey(name: 'DownloadCount')
  final int? downloadCount;
  @JsonKey(name: 'IsHashMatch')
  final bool? isHashMatch;
  @JsonKey(name: 'AiTranslated')
  final bool? aiTranslated;
  @JsonKey(name: 'MachineTranslated')
  final bool? machineTranslated;
  @JsonKey(name: 'Forced')
  final bool? forced;
  @JsonKey(name: 'HearingImpaired')
  final bool? hearingImpaired;

  Map<String, Object?> toJson() => _$RemoteSubtitleInfoToJson(this);
}
