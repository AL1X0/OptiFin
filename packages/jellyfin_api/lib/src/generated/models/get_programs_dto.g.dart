// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_programs_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetProgramsDto _$GetProgramsDtoFromJson(Map<String, dynamic> json) =>
    GetProgramsDto(
      enableTotalRecordCount: json['EnableTotalRecordCount'] as bool? ?? true,
      channelIds: (json['ChannelIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      userId: json['UserId'] as String?,
      minStartDate: json['MinStartDate'] == null
          ? null
          : DateTime.parse(json['MinStartDate'] as String),
      hasAired: json['HasAired'] as bool?,
      isAiring: json['IsAiring'] as bool?,
      maxStartDate: json['MaxStartDate'] == null
          ? null
          : DateTime.parse(json['MaxStartDate'] as String),
      minEndDate: json['MinEndDate'] == null
          ? null
          : DateTime.parse(json['MinEndDate'] as String),
      maxEndDate: json['MaxEndDate'] == null
          ? null
          : DateTime.parse(json['MaxEndDate'] as String),
      isMovie: json['IsMovie'] as bool?,
      isSeries: json['IsSeries'] as bool?,
      isNews: json['IsNews'] as bool?,
      isKids: json['IsKids'] as bool?,
      isSports: json['IsSports'] as bool?,
      startIndex: (json['StartIndex'] as num?)?.toInt(),
      limit: (json['Limit'] as num?)?.toInt(),
      sortBy: (json['SortBy'] as List<dynamic>?)
          ?.map((e) => ItemSortBy.fromJson(e as String))
          .toList(),
      sortOrder: (json['SortOrder'] as List<dynamic>?)
          ?.map(SortOrder.fromJson)
          .toList(),
      genres: (json['Genres'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      genreIds: (json['GenreIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      enableImages: json['EnableImages'] as bool?,
      imageTypeLimit: (json['ImageTypeLimit'] as num?)?.toInt(),
      enableImageTypes: (json['EnableImageTypes'] as List<dynamic>?)
          ?.map((e) => ImageType.fromJson(e as String))
          .toList(),
      enableUserData: json['EnableUserData'] as bool?,
      seriesTimerId: json['SeriesTimerId'] as String?,
      librarySeriesId: json['LibrarySeriesId'] as String?,
      fields: (json['Fields'] as List<dynamic>?)
          ?.map((e) => ItemFields.fromJson(e as String))
          .toList(),
    );

Map<String, dynamic> _$GetProgramsDtoToJson(GetProgramsDto instance) =>
    <String, dynamic>{
      'ChannelIds': ?instance.channelIds,
      'UserId': ?instance.userId,
      'MinStartDate': ?instance.minStartDate?.toIso8601String(),
      'HasAired': ?instance.hasAired,
      'IsAiring': ?instance.isAiring,
      'MaxStartDate': ?instance.maxStartDate?.toIso8601String(),
      'MinEndDate': ?instance.minEndDate?.toIso8601String(),
      'MaxEndDate': ?instance.maxEndDate?.toIso8601String(),
      'IsMovie': ?instance.isMovie,
      'IsSeries': ?instance.isSeries,
      'IsNews': ?instance.isNews,
      'IsKids': ?instance.isKids,
      'IsSports': ?instance.isSports,
      'StartIndex': ?instance.startIndex,
      'Limit': ?instance.limit,
      'SortBy': ?instance.sortBy,
      'SortOrder': ?instance.sortOrder,
      'Genres': ?instance.genres,
      'GenreIds': ?instance.genreIds,
      'EnableImages': ?instance.enableImages,
      'EnableTotalRecordCount': ?instance.enableTotalRecordCount,
      'ImageTypeLimit': ?instance.imageTypeLimit,
      'EnableImageTypes': ?instance.enableImageTypes,
      'EnableUserData': ?instance.enableUserData,
      'SeriesTimerId': ?instance.seriesTimerId,
      'LibrarySeriesId': ?instance.librarySeriesId,
      'Fields': ?instance.fields,
    };
