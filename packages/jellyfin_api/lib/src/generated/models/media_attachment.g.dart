// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_attachment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaAttachment _$MediaAttachmentFromJson(Map<String, dynamic> json) =>
    MediaAttachment(
      codec: json['Codec'] as String?,
      codecTag: json['CodecTag'] as String?,
      comment: json['Comment'] as String?,
      index: (json['Index'] as num?)?.toInt(),
      fileName: json['FileName'] as String?,
      mimeType: json['MimeType'] as String?,
      deliveryUrl: json['DeliveryUrl'] as String?,
    );

Map<String, dynamic> _$MediaAttachmentToJson(MediaAttachment instance) =>
    <String, dynamic>{
      'Codec': instance.codec,
      'CodecTag': instance.codecTag,
      'Comment': instance.comment,
      'Index': instance.index,
      'FileName': instance.fileName,
      'MimeType': instance.mimeType,
      'DeliveryUrl': instance.deliveryUrl,
    };
