// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_source_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaSourceInfo _$MediaSourceInfoFromJson(
  Map<String, dynamic> json,
) => MediaSourceInfo(
  genPtsInput: json['GenPtsInput'] as bool,
  id: json['Id'] as String?,
  path: json['Path'] as String?,
  encoderPath: json['EncoderPath'] as String?,
  encoderProtocol: json['EncoderProtocol'] == null
      ? null
      : MediaSourceInfoEncoderProtocol.fromJson(json['EncoderProtocol']),
  type: MediaSourceInfoType.fromJson(json['Type']),
  container: json['Container'] as String?,
  size: (json['Size'] as num?)?.toInt(),
  name: json['Name'] as String?,
  isRemote: json['IsRemote'] as bool,
  eTag: json['ETag'] as String?,
  runTimeTicks: (json['RunTimeTicks'] as num?)?.toInt(),
  readAtNativeFramerate: json['ReadAtNativeFramerate'] as bool,
  ignoreDts: json['IgnoreDts'] as bool,
  ignoreIndex: json['IgnoreIndex'] as bool,
  protocol: MediaSourceInfoProtocol.fromJson(json['Protocol']),
  supportsTranscoding: json['SupportsTranscoding'] as bool,
  supportsDirectStream: json['SupportsDirectStream'] as bool,
  supportsDirectPlay: json['SupportsDirectPlay'] as bool,
  isInfiniteStream: json['IsInfiniteStream'] as bool,
  defaultSubtitleStreamIndex: (json['DefaultSubtitleStreamIndex'] as num?)
      ?.toInt(),
  requiresOpening: json['RequiresOpening'] as bool,
  openToken: json['OpenToken'] as String?,
  requiresClosing: json['RequiresClosing'] as bool,
  liveStreamId: json['LiveStreamId'] as String?,
  bufferMs: (json['BufferMs'] as num?)?.toInt(),
  requiresLooping: json['RequiresLooping'] as bool,
  supportsProbing: json['SupportsProbing'] as bool,
  videoType: json['VideoType'] == null
      ? null
      : MediaSourceInfoVideoType.fromJson(json['VideoType']),
  hasSegments: json['HasSegments'] as bool,
  video3DFormat: json['Video3DFormat'] == null
      ? null
      : MediaSourceInfoVideo3DFormat.fromJson(json['Video3DFormat']),
  mediaStreams: (json['MediaStreams'] as List<dynamic>?)
      ?.map((e) => MediaStream.fromJson(e as Map<String, dynamic>))
      .toList(),
  mediaAttachments: (json['MediaAttachments'] as List<dynamic>?)
      ?.map((e) => MediaAttachment.fromJson(e as Map<String, dynamic>))
      .toList(),
  formats: (json['Formats'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  bitrate: (json['Bitrate'] as num?)?.toInt(),
  fallbackMaxStreamingBitrate: (json['FallbackMaxStreamingBitrate'] as num?)
      ?.toInt(),
  timestamp: json['Timestamp'] == null
      ? null
      : MediaSourceInfoTimestamp.fromJson(json['Timestamp']),
  requiredHttpHeaders: (json['RequiredHttpHeaders'] as Map<String, dynamic>?)
      ?.map((k, e) => MapEntry(k, e as String?)),
  transcodingUrl: json['TranscodingUrl'] as String?,
  transcodingSubProtocol: MediaSourceInfoTranscodingSubProtocol.fromJson(
    json['TranscodingSubProtocol'],
  ),
  transcodingContainer: json['TranscodingContainer'] as String?,
  analyzeDurationMs: (json['AnalyzeDurationMs'] as num?)?.toInt(),
  defaultAudioStreamIndex: (json['DefaultAudioStreamIndex'] as num?)?.toInt(),
  isoType: json['IsoType'] == null
      ? null
      : MediaSourceInfoIsoType.fromJson(json['IsoType']),
  useMostCompatibleTranscodingProfile:
      json['UseMostCompatibleTranscodingProfile'] as bool? ?? false,
);

Map<String, dynamic> _$MediaSourceInfoToJson(MediaSourceInfo instance) =>
    <String, dynamic>{
      'Protocol': instance.protocol,
      'Id': instance.id,
      'Path': instance.path,
      'EncoderPath': instance.encoderPath,
      'EncoderProtocol': instance.encoderProtocol,
      'Type': instance.type,
      'Container': instance.container,
      'Size': instance.size,
      'Name': instance.name,
      'IsRemote': instance.isRemote,
      'ETag': instance.eTag,
      'RunTimeTicks': instance.runTimeTicks,
      'ReadAtNativeFramerate': instance.readAtNativeFramerate,
      'IgnoreDts': instance.ignoreDts,
      'IgnoreIndex': instance.ignoreIndex,
      'GenPtsInput': instance.genPtsInput,
      'SupportsTranscoding': instance.supportsTranscoding,
      'SupportsDirectStream': instance.supportsDirectStream,
      'SupportsDirectPlay': instance.supportsDirectPlay,
      'IsInfiniteStream': instance.isInfiniteStream,
      'UseMostCompatibleTranscodingProfile':
          instance.useMostCompatibleTranscodingProfile,
      'RequiresOpening': instance.requiresOpening,
      'OpenToken': instance.openToken,
      'RequiresClosing': instance.requiresClosing,
      'LiveStreamId': instance.liveStreamId,
      'BufferMs': instance.bufferMs,
      'RequiresLooping': instance.requiresLooping,
      'SupportsProbing': instance.supportsProbing,
      'VideoType': instance.videoType,
      'IsoType': instance.isoType,
      'Video3DFormat': instance.video3DFormat,
      'MediaStreams': instance.mediaStreams,
      'MediaAttachments': instance.mediaAttachments,
      'Formats': instance.formats,
      'Bitrate': instance.bitrate,
      'FallbackMaxStreamingBitrate': instance.fallbackMaxStreamingBitrate,
      'Timestamp': instance.timestamp,
      'RequiredHttpHeaders': instance.requiredHttpHeaders,
      'TranscodingUrl': instance.transcodingUrl,
      'TranscodingSubProtocol': instance.transcodingSubProtocol,
      'TranscodingContainer': instance.transcodingContainer,
      'AnalyzeDurationMs': instance.analyzeDurationMs,
      'DefaultAudioStreamIndex': instance.defaultAudioStreamIndex,
      'DefaultSubtitleStreamIndex': instance.defaultSubtitleStreamIndex,
      'HasSegments': instance.hasSegments,
    };
