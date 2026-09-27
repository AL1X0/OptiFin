// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trickplay_options.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrickplayOptions _$TrickplayOptionsFromJson(Map<String, dynamic> json) =>
    TrickplayOptions(
      enableHwAcceleration: json['EnableHwAcceleration'] as bool,
      enableHwEncoding: json['EnableHwEncoding'] as bool,
      enableKeyFrameOnlyExtraction:
          json['EnableKeyFrameOnlyExtraction'] as bool,
      scanBehavior: TrickplayOptionsScanBehavior.fromJson(json['ScanBehavior']),
      processPriority: TrickplayOptionsProcessPriority.fromJson(
        json['ProcessPriority'],
      ),
      interval: (json['Interval'] as num).toInt(),
      widthResolutions: (json['WidthResolutions'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      tileWidth: (json['TileWidth'] as num).toInt(),
      tileHeight: (json['TileHeight'] as num).toInt(),
      qscale: (json['Qscale'] as num).toInt(),
      jpegQuality: (json['JpegQuality'] as num).toInt(),
      processThreads: (json['ProcessThreads'] as num).toInt(),
    );

Map<String, dynamic> _$TrickplayOptionsToJson(TrickplayOptions instance) =>
    <String, dynamic>{
      'EnableHwAcceleration': instance.enableHwAcceleration,
      'EnableHwEncoding': instance.enableHwEncoding,
      'EnableKeyFrameOnlyExtraction': instance.enableKeyFrameOnlyExtraction,
      'ScanBehavior': instance.scanBehavior,
      'ProcessPriority': instance.processPriority,
      'Interval': instance.interval,
      'WidthResolutions': instance.widthResolutions,
      'TileWidth': instance.tileWidth,
      'TileHeight': instance.tileHeight,
      'Qscale': instance.qscale,
      'JpegQuality': instance.jpegQuality,
      'ProcessThreads': instance.processThreads,
    };
