// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'client_log_document_response_dto.g.dart';

/// Client log document response dto.
@JsonSerializable()
class ClientLogDocumentResponseDto {
  const ClientLogDocumentResponseDto({
    this.fileName,
  });
  
  factory ClientLogDocumentResponseDto.fromJson(Map<String, Object?> json) => _$ClientLogDocumentResponseDtoFromJson(json);
  
  /// Gets the resulting filename.
  @JsonKey(name: 'FileName')
  final String? fileName;

  Map<String, Object?> toJson() => _$ClientLogDocumentResponseDtoToJson(this);
}
