// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recommendation_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecommendationDto _$RecommendationDtoFromJson(Map<String, dynamic> json) =>
    RecommendationDto(
      items: (json['Items'] as List<dynamic>?)
          ?.map((e) => BaseItemDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      recommendationType: json['RecommendationType'] == null
          ? null
          : RecommendationDtoRecommendationType.fromJson(
              json['RecommendationType'],
            ),
      baselineItemName: json['BaselineItemName'] as String?,
      categoryId: json['CategoryId'] as String?,
    );

Map<String, dynamic> _$RecommendationDtoToJson(RecommendationDto instance) =>
    <String, dynamic>{
      'Items': ?instance.items,
      'RecommendationType': ?instance.recommendationType,
      'BaselineItemName': ?instance.baselineItemName,
      'CategoryId': ?instance.categoryId,
    };
