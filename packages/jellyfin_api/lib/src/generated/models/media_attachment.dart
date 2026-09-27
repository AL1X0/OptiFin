// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'media_attachment.g.dart';

/// Class MediaAttachment.
@JsonSerializable()
class MediaAttachment {
  const MediaAttachment({
    this.codec,
    this.codecTag,
    this.comment,
    this.index,
    this.fileName,
    this.mimeType,
    this.deliveryUrl,
  });
  
  factory MediaAttachment.fromJson(Map<String, Object?> json) => _$MediaAttachmentFromJson(json);
  
  /// Gets or sets the codec.
  @JsonKey(name: 'Codec')
  final String? codec;

  /// Gets or sets the codec tag.
  @JsonKey(name: 'CodecTag')
  final String? codecTag;

  /// Gets or sets the comment.
  @JsonKey(name: 'Comment')
  final String? comment;

  /// Gets or sets the index.
  @JsonKey(name: 'Index')
  final int? index;

  /// Gets or sets the filename.
  @JsonKey(name: 'FileName')
  final String? fileName;

  /// Gets or sets the MIME type.
  @JsonKey(name: 'MimeType')
  final String? mimeType;

  /// Gets or sets the delivery URL.
  @JsonKey(name: 'DeliveryUrl')
  final String? deliveryUrl;

  Map<String, Object?> toJson() => _$MediaAttachmentToJson(this);
}
