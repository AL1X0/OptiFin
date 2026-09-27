// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'base_item_dto.dart';
import 'recommendation_dto_recommendation_type.dart';

part 'recommendation_dto.g.dart';

@JsonSerializable()
class RecommendationDto {
  const RecommendationDto({
    required this.items,
    required this.recommendationType,
    required this.baselineItemName,
    required this.categoryId,
  });
  
  factory RecommendationDto.fromJson(Map<String, Object?> json) => _$RecommendationDtoFromJson(json);
  
  @JsonKey(name: 'Items')
  final List<BaseItemDto>? items;
  @JsonKey(name: 'RecommendationType')
  final RecommendationDtoRecommendationType? recommendationType;
  @JsonKey(name: 'BaselineItemName')
  final String? baselineItemName;
  @JsonKey(name: 'CategoryId')
  final String? categoryId;

  Map<String, Object?> toJson() => _$RecommendationDtoToJson(this);
}
