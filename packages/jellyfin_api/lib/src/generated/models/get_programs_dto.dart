// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'image_type.dart';
import 'item_fields.dart';
import 'item_sort_by.dart';
import 'sort_order.dart';

part 'get_programs_dto.g.dart';

/// Get programs dto.
@JsonSerializable()
class GetProgramsDto {
  const GetProgramsDto({
    this.enableTotalRecordCount = true,
    this.channelIds,
    this.userId,
    this.minStartDate,
    this.hasAired,
    this.isAiring,
    this.maxStartDate,
    this.minEndDate,
    this.maxEndDate,
    this.isMovie,
    this.isSeries,
    this.isNews,
    this.isKids,
    this.isSports,
    this.startIndex,
    this.limit,
    this.sortBy,
    this.sortOrder,
    this.genres,
    this.genreIds,
    this.enableImages,
    this.imageTypeLimit,
    this.enableImageTypes,
    this.enableUserData,
    this.seriesTimerId,
    this.librarySeriesId,
    this.fields,
  });
  
  factory GetProgramsDto.fromJson(Map<String, Object?> json) => _$GetProgramsDtoFromJson(json);
  
  /// Gets or sets the channels to return guide information for.
  @JsonKey(name: 'ChannelIds')
  final List<String>? channelIds;

  /// Gets or sets optional. Filter by user id.
  @JsonKey(name: 'UserId')
  final String? userId;

  /// Gets or sets the minimum premiere start date.
  @JsonKey(name: 'MinStartDate')
  final DateTime? minStartDate;

  /// Gets or sets filter by programs that have completed airing, or not.
  @JsonKey(name: 'HasAired')
  final bool? hasAired;

  /// Gets or sets filter by programs that are currently airing, or not.
  @JsonKey(name: 'IsAiring')
  final bool? isAiring;

  /// Gets or sets the maximum premiere start date.
  @JsonKey(name: 'MaxStartDate')
  final DateTime? maxStartDate;

  /// Gets or sets the minimum premiere end date.
  @JsonKey(name: 'MinEndDate')
  final DateTime? minEndDate;

  /// Gets or sets the maximum premiere end date.
  @JsonKey(name: 'MaxEndDate')
  final DateTime? maxEndDate;

  /// Gets or sets filter for movies.
  @JsonKey(name: 'IsMovie')
  final bool? isMovie;

  /// Gets or sets filter for series.
  @JsonKey(name: 'IsSeries')
  final bool? isSeries;

  /// Gets or sets filter for news.
  @JsonKey(name: 'IsNews')
  final bool? isNews;

  /// Gets or sets filter for kids.
  @JsonKey(name: 'IsKids')
  final bool? isKids;

  /// Gets or sets filter for sports.
  @JsonKey(name: 'IsSports')
  final bool? isSports;

  /// Gets or sets the record index to start at. All items with a lower index will be dropped from the results.
  @JsonKey(name: 'StartIndex')
  final int? startIndex;

  /// Gets or sets the maximum number of records to return.
  @JsonKey(name: 'Limit')
  final int? limit;

  /// Gets or sets specify one or more sort orders, comma delimited. Options: Name, StartDate.
  @JsonKey(name: 'SortBy')
  final List<ItemSortBy>? sortBy;

  /// Gets or sets sort order.
  @JsonKey(name: 'SortOrder')
  final List<SortOrder>? sortOrder;

  /// Gets or sets the genres to return guide information for.
  @JsonKey(name: 'Genres')
  final List<String>? genres;

  /// Gets or sets the genre ids to return guide information for.
  @JsonKey(name: 'GenreIds')
  final List<String>? genreIds;

  /// Gets or sets include image information in output.
  @JsonKey(name: 'EnableImages')
  final bool? enableImages;

  /// Gets or sets a value indicating whether retrieve total record count.
  @JsonKey(name: 'EnableTotalRecordCount')
  final bool? enableTotalRecordCount;

  /// Gets or sets the max number of images to return, per image type.
  @JsonKey(name: 'ImageTypeLimit')
  final int? imageTypeLimit;

  /// Gets or sets the image types to include in the output.
  @JsonKey(name: 'EnableImageTypes')
  final List<ImageType>? enableImageTypes;

  /// Gets or sets include user data.
  @JsonKey(name: 'EnableUserData')
  final bool? enableUserData;

  /// Gets or sets filter by series timer id.
  @JsonKey(name: 'SeriesTimerId')
  final String? seriesTimerId;

  /// Gets or sets filter by library series id.
  @JsonKey(name: 'LibrarySeriesId')
  final String? librarySeriesId;

  /// Gets or sets specify additional fields of information to return in the output.
  @JsonKey(name: 'Fields')
  final List<ItemFields>? fields;

  Map<String, Object?> toJson() => _$GetProgramsDtoToJson(this);
}
