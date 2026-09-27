// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'tuner_host_info.g.dart';

@JsonSerializable()
class TunerHostInfo {
  const TunerHostInfo({
    this.id,
    this.url,
    this.type,
    this.deviceId,
    this.friendlyName,
    this.importFavoritesOnly,
    this.allowHwTranscoding,
    this.allowFmp4TranscodingContainer,
    this.allowStreamSharing,
    this.fallbackMaxStreamingBitrate,
    this.enableStreamLooping,
    this.source,
    this.tunerCount,
    this.userAgent,
    this.ignoreDts,
    this.readAtNativeFramerate,
  });
  
  factory TunerHostInfo.fromJson(Map<String, Object?> json) => _$TunerHostInfoFromJson(json);
  
  @JsonKey(name: 'Id')
  final String? id;
  @JsonKey(name: 'Url')
  final String? url;
  @JsonKey(name: 'Type')
  final String? type;
  @JsonKey(name: 'DeviceId')
  final String? deviceId;
  @JsonKey(name: 'FriendlyName')
  final String? friendlyName;
  @JsonKey(name: 'ImportFavoritesOnly')
  final bool? importFavoritesOnly;
  @JsonKey(name: 'AllowHWTranscoding')
  final bool? allowHwTranscoding;
  @JsonKey(name: 'AllowFmp4TranscodingContainer')
  final bool? allowFmp4TranscodingContainer;
  @JsonKey(name: 'AllowStreamSharing')
  final bool? allowStreamSharing;
  @JsonKey(name: 'FallbackMaxStreamingBitrate')
  final int? fallbackMaxStreamingBitrate;
  @JsonKey(name: 'EnableStreamLooping')
  final bool? enableStreamLooping;
  @JsonKey(name: 'Source')
  final String? source;
  @JsonKey(name: 'TunerCount')
  final int? tunerCount;
  @JsonKey(name: 'UserAgent')
  final String? userAgent;
  @JsonKey(name: 'IgnoreDts')
  final bool? ignoreDts;
  @JsonKey(name: 'ReadAtNativeFramerate')
  final bool? readAtNativeFramerate;

  Map<String, Object?> toJson() => _$TunerHostInfoToJson(this);
}
