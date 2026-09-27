// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tuner_host_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TunerHostInfo _$TunerHostInfoFromJson(Map<String, dynamic> json) =>
    TunerHostInfo(
      id: json['Id'] as String?,
      url: json['Url'] as String?,
      type: json['Type'] as String?,
      deviceId: json['DeviceId'] as String?,
      friendlyName: json['FriendlyName'] as String?,
      importFavoritesOnly: json['ImportFavoritesOnly'] as bool?,
      allowHwTranscoding: json['AllowHWTranscoding'] as bool?,
      allowFmp4TranscodingContainer:
          json['AllowFmp4TranscodingContainer'] as bool?,
      allowStreamSharing: json['AllowStreamSharing'] as bool?,
      fallbackMaxStreamingBitrate: (json['FallbackMaxStreamingBitrate'] as num?)
          ?.toInt(),
      enableStreamLooping: json['EnableStreamLooping'] as bool?,
      source: json['Source'] as String?,
      tunerCount: (json['TunerCount'] as num?)?.toInt(),
      userAgent: json['UserAgent'] as String?,
      ignoreDts: json['IgnoreDts'] as bool?,
      readAtNativeFramerate: json['ReadAtNativeFramerate'] as bool?,
    );

Map<String, dynamic> _$TunerHostInfoToJson(TunerHostInfo instance) =>
    <String, dynamic>{
      'Id': instance.id,
      'Url': instance.url,
      'Type': instance.type,
      'DeviceId': instance.deviceId,
      'FriendlyName': instance.friendlyName,
      'ImportFavoritesOnly': instance.importFavoritesOnly,
      'AllowHWTranscoding': instance.allowHwTranscoding,
      'AllowFmp4TranscodingContainer': instance.allowFmp4TranscodingContainer,
      'AllowStreamSharing': instance.allowStreamSharing,
      'FallbackMaxStreamingBitrate': instance.fallbackMaxStreamingBitrate,
      'EnableStreamLooping': instance.enableStreamLooping,
      'Source': instance.source,
      'TunerCount': instance.tunerCount,
      'UserAgent': instance.userAgent,
      'IgnoreDts': instance.ignoreDts,
      'ReadAtNativeFramerate': instance.readAtNativeFramerate,
    };
