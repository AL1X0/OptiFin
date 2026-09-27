// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'end_point_info.g.dart';

@JsonSerializable()
class EndPointInfo {
  const EndPointInfo({
    this.isLocal,
    this.isInNetwork,
  });
  
  factory EndPointInfo.fromJson(Map<String, Object?> json) => _$EndPointInfoFromJson(json);
  
  @JsonKey(name: 'IsLocal')
  final bool? isLocal;
  @JsonKey(name: 'IsInNetwork')
  final bool? isInNetwork;

  Map<String, Object?> toJson() => _$EndPointInfoToJson(this);
}
