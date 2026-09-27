// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'media_attachment.dart';
import 'media_source_info_encoder_protocol.dart';
import 'media_source_info_iso_type.dart';
import 'media_source_info_protocol.dart';
import 'media_source_info_timestamp.dart';
import 'media_source_info_transcoding_sub_protocol.dart';
import 'media_source_info_type.dart';
import 'media_source_info_video3_d_format.dart';
import 'media_source_info_video_type.dart';
import 'media_stream.dart';

part 'media_source_info.g.dart';

@JsonSerializable()
class MediaSourceInfo {
  const MediaSourceInfo({
    required this.genPtsInput,
    required this.id,
    required this.path,
    required this.encoderPath,
    required this.encoderProtocol,
    required this.type,
    required this.container,
    required this.size,
    required this.name,
    required this.isRemote,
    required this.eTag,
    required this.runTimeTicks,
    required this.readAtNativeFramerate,
    required this.ignoreDts,
    required this.ignoreIndex,
    required this.protocol,
    required this.supportsTranscoding,
    required this.supportsDirectStream,
    required this.supportsDirectPlay,
    required this.isInfiniteStream,
    required this.defaultSubtitleStreamIndex,
    required this.requiresOpening,
    required this.openToken,
    required this.requiresClosing,
    required this.liveStreamId,
    required this.bufferMs,
    required this.requiresLooping,
    required this.supportsProbing,
    required this.videoType,
    required this.hasSegments,
    required this.video3DFormat,
    required this.mediaStreams,
    required this.mediaAttachments,
    required this.formats,
    required this.bitrate,
    required this.fallbackMaxStreamingBitrate,
    required this.timestamp,
    required this.requiredHttpHeaders,
    required this.transcodingUrl,
    required this.transcodingSubProtocol,
    required this.transcodingContainer,
    required this.analyzeDurationMs,
    required this.defaultAudioStreamIndex,
    required this.isoType,
    this.useMostCompatibleTranscodingProfile = false,
  });
  
  factory MediaSourceInfo.fromJson(Map<String, Object?> json) => _$MediaSourceInfoFromJson(json);
  
  @JsonKey(name: 'Protocol')
  final MediaSourceInfoProtocol protocol;
  @JsonKey(name: 'Id')
  final String? id;
  @JsonKey(name: 'Path')
  final String? path;
  @JsonKey(name: 'EncoderPath')
  final String? encoderPath;
  @JsonKey(name: 'EncoderProtocol')
  final MediaSourceInfoEncoderProtocol? encoderProtocol;

  /// The type of a media source.
  @JsonKey(name: 'Type')
  final MediaSourceInfoType type;
  @JsonKey(name: 'Container')
  final String? container;
  @JsonKey(name: 'Size')
  final int? size;
  @JsonKey(name: 'Name')
  final String? name;

  /// Gets or sets a value indicating whether the media is remote.
  /// Differentiate internet url vs local network.
  @JsonKey(name: 'IsRemote')
  final bool isRemote;
  @JsonKey(name: 'ETag')
  final String? eTag;
  @JsonKey(name: 'RunTimeTicks')
  final int? runTimeTicks;
  @JsonKey(name: 'ReadAtNativeFramerate')
  final bool readAtNativeFramerate;
  @JsonKey(name: 'IgnoreDts')
  final bool ignoreDts;
  @JsonKey(name: 'IgnoreIndex')
  final bool ignoreIndex;
  @JsonKey(name: 'GenPtsInput')
  final bool genPtsInput;
  @JsonKey(name: 'SupportsTranscoding')
  final bool supportsTranscoding;
  @JsonKey(name: 'SupportsDirectStream')
  final bool supportsDirectStream;
  @JsonKey(name: 'SupportsDirectPlay')
  final bool supportsDirectPlay;
  @JsonKey(name: 'IsInfiniteStream')
  final bool isInfiniteStream;
  @JsonKey(name: 'UseMostCompatibleTranscodingProfile')
  final bool useMostCompatibleTranscodingProfile;
  @JsonKey(name: 'RequiresOpening')
  final bool requiresOpening;
  @JsonKey(name: 'OpenToken')
  final String? openToken;
  @JsonKey(name: 'RequiresClosing')
  final bool requiresClosing;
  @JsonKey(name: 'LiveStreamId')
  final String? liveStreamId;
  @JsonKey(name: 'BufferMs')
  final int? bufferMs;
  @JsonKey(name: 'RequiresLooping')
  final bool requiresLooping;
  @JsonKey(name: 'SupportsProbing')
  final bool supportsProbing;
  @JsonKey(name: 'VideoType')
  final MediaSourceInfoVideoType? videoType;
  @JsonKey(name: 'IsoType')
  final MediaSourceInfoIsoType? isoType;
  @JsonKey(name: 'Video3DFormat')
  final MediaSourceInfoVideo3DFormat? video3DFormat;
  @JsonKey(name: 'MediaStreams')
  final List<MediaStream>? mediaStreams;
  @JsonKey(name: 'MediaAttachments')
  final List<MediaAttachment>? mediaAttachments;
  @JsonKey(name: 'Formats')
  final List<String>? formats;
  @JsonKey(name: 'Bitrate')
  final int? bitrate;
  @JsonKey(name: 'FallbackMaxStreamingBitrate')
  final int? fallbackMaxStreamingBitrate;
  @JsonKey(name: 'Timestamp')
  final MediaSourceInfoTimestamp? timestamp;
  @JsonKey(name: 'RequiredHttpHeaders')
  final Map<String, String?>? requiredHttpHeaders;
  @JsonKey(name: 'TranscodingUrl')
  final String? transcodingUrl;

  /// Media streaming protocol.
  /// Lowercase for backwards compatibility.
  @JsonKey(name: 'TranscodingSubProtocol')
  final MediaSourceInfoTranscodingSubProtocol transcodingSubProtocol;
  @JsonKey(name: 'TranscodingContainer')
  final String? transcodingContainer;
  @JsonKey(name: 'AnalyzeDurationMs')
  final int? analyzeDurationMs;
  @JsonKey(name: 'DefaultAudioStreamIndex')
  final int? defaultAudioStreamIndex;
  @JsonKey(name: 'DefaultSubtitleStreamIndex')
  final int? defaultSubtitleStreamIndex;
  @JsonKey(name: 'HasSegments')
  final bool hasSegments;

  Map<String, Object?> toJson() => _$MediaSourceInfoToJson(this);
}
