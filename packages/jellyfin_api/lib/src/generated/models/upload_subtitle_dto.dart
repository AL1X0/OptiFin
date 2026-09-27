// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'upload_subtitle_dto.g.dart';

/// Upload subtitles dto.
@JsonSerializable()
class UploadSubtitleDto {
  const UploadSubtitleDto({
    this.language,
    this.format,
    this.isForced,
    this.isHearingImpaired,
    this.data,
  });
  
  factory UploadSubtitleDto.fromJson(Map<String, Object?> json) => _$UploadSubtitleDtoFromJson(json);
  
  /// Gets or sets the subtitle language.
  @JsonKey(name: 'Language')
  final String? language;

  /// Gets or sets the subtitle format.
  @JsonKey(name: 'Format')
  final String? format;

  /// Gets or sets a value indicating whether the subtitle is forced.
  @JsonKey(name: 'IsForced')
  final bool? isForced;

  /// Gets or sets a value indicating whether the subtitle is for hearing impaired.
  @JsonKey(name: 'IsHearingImpaired')
  final bool? isHearingImpaired;

  /// Gets or sets the subtitle data.
  @JsonKey(name: 'Data')
  final String? data;

  Map<String, Object?> toJson() => _$UploadSubtitleDtoToJson(this);
}
