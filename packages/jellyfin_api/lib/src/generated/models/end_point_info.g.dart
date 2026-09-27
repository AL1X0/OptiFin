// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'end_point_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EndPointInfo _$EndPointInfoFromJson(Map<String, dynamic> json) => EndPointInfo(
  isLocal: json['IsLocal'] as bool?,
  isInNetwork: json['IsInNetwork'] as bool?,
);

Map<String, dynamic> _$EndPointInfoToJson(EndPointInfo instance) =>
    <String, dynamic>{
      'IsLocal': instance.isLocal,
      'IsInNetwork': instance.isInNetwork,
    };
