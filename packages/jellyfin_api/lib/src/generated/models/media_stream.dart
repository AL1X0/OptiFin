// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'media_stream_audio_spatial_format.dart';
import 'media_stream_delivery_method.dart';
import 'media_stream_type.dart';
import 'media_stream_video_range.dart';
import 'media_stream_video_range_type.dart';

part 'media_stream.g.dart';

/// Class MediaStream.
@JsonSerializable()
class MediaStream {
  const MediaStream({
    required this.videoRangeType,
    required this.codecTag,
    required this.language,
    required this.colorRange,
    required this.colorSpace,
    required this.colorTransfer,
    required this.colorPrimaries,
    required this.dvVersionMajor,
    required this.dvVersionMinor,
    required this.dvProfile,
    required this.dvLevel,
    required this.rpuPresentFlag,
    required this.elPresentFlag,
    required this.blPresentFlag,
    required this.dvBlSignalCompatibilityId,
    required this.rotation,
    required this.comment,
    required this.timeBase,
    required this.codecTimeBase,
    required this.title,
    required this.hdr10PlusPresentFlag,
    required this.videoRange,
    required this.codec,
    required this.videoDoViTitle,
    required this.audioSpatialFormat,
    required this.localizedUndefined,
    required this.localizedDefault,
    required this.localizedForced,
    required this.localizedExternal,
    required this.localizedHearingImpaired,
    required this.localizedLanguage,
    required this.localizedOriginal,
    required this.displayTitle,
    required this.nalLengthSize,
    required this.isInterlaced,
    required this.isAvc,
    required this.channelLayout,
    required this.bitRate,
    required this.bitDepth,
    required this.refFrames,
    required this.packetLength,
    required this.channels,
    required this.sampleRate,
    required this.isDefault,
    required this.isAnamorphic,
    required this.isHearingImpaired,
    required this.isOriginal,
    required this.height,
    required this.width,
    required this.averageFrameRate,
    required this.realFrameRate,
    required this.referenceFrameRate,
    required this.profile,
    required this.type,
    required this.aspectRatio,
    required this.index,
    required this.score,
    required this.isExternal,
    required this.deliveryMethod,
    required this.deliveryUrl,
    required this.isExternalUrl,
    required this.isTextSubtitleStream,
    required this.supportsExternalStream,
    required this.path,
    required this.pixelFormat,
    required this.level,
    required this.isForced,
  });
  
  factory MediaStream.fromJson(Map<String, Object?> json) => _$MediaStreamFromJson(json);
  
  /// Gets or sets the codec.
  @JsonKey(name: 'Codec')
  final String? codec;

  /// Gets or sets the codec tag.
  @JsonKey(name: 'CodecTag')
  final String? codecTag;

  /// Gets or sets the language.
  @JsonKey(name: 'Language')
  final String? language;

  /// Gets or sets the color range.
  @JsonKey(name: 'ColorRange')
  final String? colorRange;

  /// Gets or sets the color space.
  @JsonKey(name: 'ColorSpace')
  final String? colorSpace;

  /// Gets or sets the color transfer.
  @JsonKey(name: 'ColorTransfer')
  final String? colorTransfer;

  /// Gets or sets the color primaries.
  @JsonKey(name: 'ColorPrimaries')
  final String? colorPrimaries;

  /// Gets or sets the Dolby Vision version major.
  @JsonKey(name: 'DvVersionMajor')
  final int? dvVersionMajor;

  /// Gets or sets the Dolby Vision version minor.
  @JsonKey(name: 'DvVersionMinor')
  final int? dvVersionMinor;

  /// Gets or sets the Dolby Vision profile.
  @JsonKey(name: 'DvProfile')
  final int? dvProfile;

  /// Gets or sets the Dolby Vision level.
  @JsonKey(name: 'DvLevel')
  final int? dvLevel;

  /// Gets or sets the Dolby Vision rpu present flag.
  @JsonKey(name: 'RpuPresentFlag')
  final int? rpuPresentFlag;

  /// Gets or sets the Dolby Vision el present flag.
  @JsonKey(name: 'ElPresentFlag')
  final int? elPresentFlag;

  /// Gets or sets the Dolby Vision bl present flag.
  @JsonKey(name: 'BlPresentFlag')
  final int? blPresentFlag;

  /// Gets or sets the Dolby Vision bl signal compatibility id.
  @JsonKey(name: 'DvBlSignalCompatibilityId')
  final int? dvBlSignalCompatibilityId;

  /// Gets or sets the Rotation in degrees.
  @JsonKey(name: 'Rotation')
  final int? rotation;

  /// Gets or sets the comment.
  @JsonKey(name: 'Comment')
  final String? comment;

  /// Gets or sets the time base.
  @JsonKey(name: 'TimeBase')
  final String? timeBase;

  /// Gets or sets the codec time base.
  @JsonKey(name: 'CodecTimeBase')
  final String? codecTimeBase;

  /// Gets or sets the title.
  @JsonKey(name: 'Title')
  final String? title;
  @JsonKey(name: 'Hdr10PlusPresentFlag')
  final bool? hdr10PlusPresentFlag;

  /// An enum representing video ranges.
  @JsonKey(name: 'VideoRange')
  final MediaStreamVideoRange? videoRange;

  /// An enum representing types of video ranges.
  @JsonKey(name: 'VideoRangeType')
  final MediaStreamVideoRangeType? videoRangeType;

  /// Gets the video dovi title.
  @JsonKey(name: 'VideoDoViTitle')
  final String? videoDoViTitle;

  /// An enum representing formats of spatial audio.
  @JsonKey(name: 'AudioSpatialFormat')
  final MediaStreamAudioSpatialFormat? audioSpatialFormat;
  @JsonKey(name: 'LocalizedUndefined')
  final String? localizedUndefined;
  @JsonKey(name: 'LocalizedDefault')
  final String? localizedDefault;
  @JsonKey(name: 'LocalizedForced')
  final String? localizedForced;
  @JsonKey(name: 'LocalizedExternal')
  final String? localizedExternal;
  @JsonKey(name: 'LocalizedHearingImpaired')
  final String? localizedHearingImpaired;
  @JsonKey(name: 'LocalizedLanguage')
  final String? localizedLanguage;
  @JsonKey(name: 'LocalizedOriginal')
  final String? localizedOriginal;
  @JsonKey(name: 'DisplayTitle')
  final String? displayTitle;
  @JsonKey(name: 'NalLengthSize')
  final String? nalLengthSize;

  /// Gets or sets a value indicating whether this instance is interlaced.
  @JsonKey(name: 'IsInterlaced')
  final bool? isInterlaced;
  @JsonKey(name: 'IsAVC')
  final bool? isAvc;

  /// Gets or sets the channel layout.
  @JsonKey(name: 'ChannelLayout')
  final String? channelLayout;

  /// Gets or sets the bit rate.
  @JsonKey(name: 'BitRate')
  final int? bitRate;

  /// Gets or sets the bit depth.
  @JsonKey(name: 'BitDepth')
  final int? bitDepth;

  /// Gets or sets the reference frames.
  @JsonKey(name: 'RefFrames')
  final int? refFrames;

  /// Gets or sets the length of the packet.
  @JsonKey(name: 'PacketLength')
  final int? packetLength;

  /// Gets or sets the channels.
  @JsonKey(name: 'Channels')
  final int? channels;

  /// Gets or sets the sample rate.
  @JsonKey(name: 'SampleRate')
  final int? sampleRate;

  /// Gets or sets a value indicating whether this instance is default.
  @JsonKey(name: 'IsDefault')
  final bool? isDefault;

  /// Gets or sets a value indicating whether this instance is forced.
  @JsonKey(name: 'IsForced')
  final bool? isForced;

  /// Gets or sets a value indicating whether this instance is for the hearing impaired.
  @JsonKey(name: 'IsHearingImpaired')
  final bool? isHearingImpaired;

  /// Gets or sets a value indicating whether this instance is original.
  @JsonKey(name: 'IsOriginal')
  final bool? isOriginal;

  /// Gets or sets the height.
  @JsonKey(name: 'Height')
  final int? height;

  /// Gets or sets the width.
  @JsonKey(name: 'Width')
  final int? width;

  /// Gets or sets the average frame rate.
  @JsonKey(name: 'AverageFrameRate')
  final double? averageFrameRate;

  /// Gets or sets the real frame rate.
  @JsonKey(name: 'RealFrameRate')
  final double? realFrameRate;

  /// Gets the framerate used as reference.
  /// Prefer AverageFrameRate, if that is null or an unrealistic value.
  /// then fallback to RealFrameRate.
  @JsonKey(name: 'ReferenceFrameRate')
  final double? referenceFrameRate;

  /// Gets or sets the profile.
  @JsonKey(name: 'Profile')
  final String? profile;

  /// Gets or sets the type.
  @JsonKey(name: 'Type')
  final MediaStreamType? type;

  /// Gets or sets the aspect ratio.
  @JsonKey(name: 'AspectRatio')
  final String? aspectRatio;

  /// Gets or sets the index.
  @JsonKey(name: 'Index')
  final int? index;

  /// Gets or sets the score.
  @JsonKey(name: 'Score')
  final int? score;

  /// Gets or sets a value indicating whether this instance is external.
  @JsonKey(name: 'IsExternal')
  final bool? isExternal;

  /// Gets or sets the method.
  @JsonKey(name: 'DeliveryMethod')
  final MediaStreamDeliveryMethod? deliveryMethod;

  /// Gets or sets the delivery URL.
  @JsonKey(name: 'DeliveryUrl')
  final String? deliveryUrl;

  /// Gets or sets a value indicating whether this instance is external URL.
  @JsonKey(name: 'IsExternalUrl')
  final bool? isExternalUrl;
  @JsonKey(name: 'IsTextSubtitleStream')
  final bool? isTextSubtitleStream;

  /// Gets or sets a value indicating whether [supports external stream].
  @JsonKey(name: 'SupportsExternalStream')
  final bool? supportsExternalStream;

  /// Gets or sets the filename.
  @JsonKey(name: 'Path')
  final String? path;

  /// Gets or sets the pixel format.
  @JsonKey(name: 'PixelFormat')
  final String? pixelFormat;

  /// Gets or sets the level.
  @JsonKey(name: 'Level')
  final double? level;

  /// Gets or sets whether this instance is anamorphic.
  @JsonKey(name: 'IsAnamorphic')
  final bool? isAnamorphic;

  Map<String, Object?> toJson() => _$MediaStreamToJson(this);
}
