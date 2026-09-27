// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trailer_client.dart';

// dart format off

// **************************************************************************
// RetrofitGenerator
// **************************************************************************

// ignore_for_file: type=lint
// ignore_for_file: unnecessary_brace_in_string_interps,no_leading_underscores_for_local_identifiers,unused_element,unnecessary_string_interpolations,unused_element_parameter,avoid_unused_constructor_parameters,unreachable_from_main,avoid_redundant_argument_values

class _TrailerClient implements TrailerClient {
  _TrailerClient(this._dio, {this.baseUrl, this.errorLogger});

  final Dio _dio;

  String? baseUrl;

  final ParseErrorLogger? errorLogger;

  @override
  Future<BaseItemDtoQueryResult> getTrailers({
    bool? isNews,
    String? maxOfficialRating,
    bool? hasThemeSong,
    bool? hasThemeVideo,
    bool? hasSubtitles,
    bool? hasSpecialFeature,
    bool? hasTrailer,
    String? adjacentTo,
    int? parentIndexNumber,
    bool? hasParentalRating,
    bool? isHd,
    bool? is4K,
    List<LocationType>? locationTypes,
    List<LocationType>? excludeLocationTypes,
    bool? isMissing,
    bool? isUnaired,
    double? minCommunityRating,
    double? minCriticRating,
    DateTime? minPremiereDate,
    DateTime? minDateLastSaved,
    DateTime? minDateLastSavedForUser,
    DateTime? maxPremiereDate,
    bool? hasOverview,
    bool? hasImdbId,
    bool? hasTmdbId,
    bool? hasTvdbId,
    bool? isMovie,
    bool? isSeries,
    String? userId,
    bool? isKids,
    bool? isSports,
    List<String>? excludeItemIds,
    int? startIndex,
    int? limit,
    bool? recursive,
    String? searchTerm,
    List<SortOrder>? sortOrder,
    String? parentId,
    List<ItemFields>? fields,
    List<BaseItemKind>? excludeItemTypes,
    List<ItemFilter>? filters,
    bool? isFavorite,
    List<MediaType>? mediaTypes,
    List<ImageType>? imageTypes,
    List<ItemSortBy>? sortBy,
    bool? isPlayed,
    List<String>? genres,
    List<String>? officialRatings,
    List<String>? tags,
    List<int>? years,
    bool? enableUserData,
    int? imageTypeLimit,
    List<ImageType>? enableImageTypes,
    String? person,
    List<String>? personIds,
    List<String>? personTypes,
    List<String>? subtitleLanguages,
    List<String>? artists,
    List<String>? excludeArtistIds,
    List<String>? artistIds,
    List<String>? albumArtistIds,
    List<String>? contributingArtistIds,
    List<String>? albums,
    List<String>? albumIds,
    List<String>? ids,
    List<VideoType>? videoTypes,
    String? minOfficialRating,
    bool? isLocked,
    bool? isPlaceHolder,
    bool? hasOfficialRating,
    bool? collapseBoxSetItems,
    int? minWidth,
    int? minHeight,
    int? maxWidth,
    int? maxHeight,
    bool? is3D,
    List<SeriesStatus>? seriesStatus,
    String? nameStartsWithOrGreater,
    String? nameStartsWith,
    String? nameLessThan,
    List<String>? studioIds,
    List<String>? genreIds,
    List<String>? audioLanguages,
    List<String>? studios,
    bool? enableTotalRecordCount = true,
    bool? enableImages = true,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'isNews': isNews,
      r'maxOfficialRating': maxOfficialRating,
      r'hasThemeSong': hasThemeSong,
      r'hasThemeVideo': hasThemeVideo,
      r'hasSubtitles': hasSubtitles,
      r'hasSpecialFeature': hasSpecialFeature,
      r'hasTrailer': hasTrailer,
      r'adjacentTo': adjacentTo,
      r'parentIndexNumber': parentIndexNumber,
      r'hasParentalRating': hasParentalRating,
      r'isHd': isHd,
      r'is4K': is4K,
      r'locationTypes': locationTypes,
      r'excludeLocationTypes': excludeLocationTypes,
      r'isMissing': isMissing,
      r'isUnaired': isUnaired,
      r'minCommunityRating': minCommunityRating,
      r'minCriticRating': minCriticRating,
      r'minPremiereDate': minPremiereDate?.toIso8601String(),
      r'minDateLastSaved': minDateLastSaved?.toIso8601String(),
      r'minDateLastSavedForUser': minDateLastSavedForUser?.toIso8601String(),
      r'maxPremiereDate': maxPremiereDate?.toIso8601String(),
      r'hasOverview': hasOverview,
      r'hasImdbId': hasImdbId,
      r'hasTmdbId': hasTmdbId,
      r'hasTvdbId': hasTvdbId,
      r'isMovie': isMovie,
      r'isSeries': isSeries,
      r'userId': userId,
      r'isKids': isKids,
      r'isSports': isSports,
      r'excludeItemIds': excludeItemIds,
      r'startIndex': startIndex,
      r'limit': limit,
      r'recursive': recursive,
      r'searchTerm': searchTerm,
      r'sortOrder': sortOrder,
      r'parentId': parentId,
      r'fields': fields,
      r'excludeItemTypes': excludeItemTypes,
      r'filters': filters,
      r'isFavorite': isFavorite,
      r'mediaTypes': mediaTypes,
      r'imageTypes': imageTypes,
      r'sortBy': sortBy,
      r'isPlayed': isPlayed,
      r'genres': genres,
      r'officialRatings': officialRatings,
      r'tags': tags,
      r'years': years,
      r'enableUserData': enableUserData,
      r'imageTypeLimit': imageTypeLimit,
      r'enableImageTypes': enableImageTypes,
      r'person': person,
      r'personIds': personIds,
      r'personTypes': personTypes,
      r'subtitleLanguages': subtitleLanguages,
      r'artists': artists,
      r'excludeArtistIds': excludeArtistIds,
      r'artistIds': artistIds,
      r'albumArtistIds': albumArtistIds,
      r'contributingArtistIds': contributingArtistIds,
      r'albums': albums,
      r'albumIds': albumIds,
      r'ids': ids,
      r'videoTypes': videoTypes,
      r'minOfficialRating': minOfficialRating,
      r'isLocked': isLocked,
      r'isPlaceHolder': isPlaceHolder,
      r'hasOfficialRating': hasOfficialRating,
      r'collapseBoxSetItems': collapseBoxSetItems,
      r'minWidth': minWidth,
      r'minHeight': minHeight,
      r'maxWidth': maxWidth,
      r'maxHeight': maxHeight,
      r'is3D': is3D,
      r'seriesStatus': seriesStatus,
      r'nameStartsWithOrGreater': nameStartsWithOrGreater,
      r'nameStartsWith': nameStartsWith,
      r'nameLessThan': nameLessThan,
      r'studioIds': studioIds,
      r'genreIds': genreIds,
      r'audioLanguages': audioLanguages,
      r'studios': studios,
      r'enableTotalRecordCount': enableTotalRecordCount,
      r'enableImages': enableImages,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<BaseItemDtoQueryResult>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/Trailers',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late BaseItemDtoQueryResult _value;
    try {
      _value = BaseItemDtoQueryResult.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  RequestOptions _setStreamType<T>(RequestOptions requestOptions) {
    if (T != dynamic &&
        !(requestOptions.responseType == ResponseType.bytes ||
            requestOptions.responseType == ResponseType.stream)) {
      if (T == String) {
        requestOptions.responseType = ResponseType.plain;
      } else {
        requestOptions.responseType = ResponseType.json;
      }
    }
    return requestOptions;
  }

  String _combineBaseUrls(String dioBaseUrl, String? baseUrl) {
    if (baseUrl == null || baseUrl.trim().isEmpty) {
      return dioBaseUrl;
    }

    final url = Uri.parse(baseUrl);

    if (url.isAbsolute) {
      return url.toString();
    }

    return Uri.parse(dioBaseUrl).resolveUri(url).toString();
  }
}

// dart format on
