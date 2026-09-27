// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/base_item_dto_query_result.dart';
import '../models/collection_type.dart';
import '../models/special_view_option_dto.dart';

part 'user_view_client.g.dart';

@RestApi()
abstract class UserViewClient {
  factory UserViewClient(Dio dio, {String? baseUrl}) = _UserViewClient;

  /// Get user views.
  ///
  /// [userId] - User id.
  ///
  /// [includeExternalContent] - Whether or not to include external views such as channels or live tv.
  ///
  /// [presetViews] - Preset views.
  ///
  /// [includeHidden] - Whether or not to include hidden content.
  @GET('/UserViews')
  Future<BaseItemDtoQueryResult> getUserViews({
    @Query('includeHidden') bool? includeHidden = false,
    @Query('userId') String? userId,
    @Query('includeExternalContent') bool? includeExternalContent,
    @Query('presetViews') List<CollectionType>? presetViews,
  });

  /// Get user view grouping options.
  ///
  /// [userId] - User id.
  @GET('/UserViews/GroupingOptions')
  Future<List<SpecialViewOptionDto>> getGroupingOptions({
    @Query('userId') String? userId,
  });
}
