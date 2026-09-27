// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'artist_client.dart';

// dart format off

// **************************************************************************
// RetrofitGenerator
// **************************************************************************

// ignore_for_file: type=lint
// ignore_for_file: unnecessary_brace_in_string_interps,no_leading_underscores_for_local_identifiers,unused_element,unnecessary_string_interpolations,unused_element_parameter,avoid_unused_constructor_parameters,unreachable_from_main,avoid_redundant_argument_values

class _ArtistClient implements ArtistClient {
  _ArtistClient(this._dio, {this.baseUrl, this.errorLogger});

  final Dio _dio;

  String? baseUrl;

  final ParseErrorLogger? errorLogger;

  @override
  Future<BaseItemDtoQueryResult> getArtists({
    bool? enableImages = true,
    bool? enableTotalRecordCount = true,
    double? minCommunityRating,
    int? startIndex,
    int? limit,
    String? searchTerm,
    String? parentId,
    List<ItemFields>? fields,
    List<BaseItemKind>? excludeItemTypes,
    List<BaseItemKind>? includeItemTypes,
    List<ItemFilter>? filters,
    bool? isFavorite,
    List<MediaType>? mediaTypes,
    List<String>? genres,
    List<String>? genreIds,
    List<String>? officialRatings,
    List<String>? tags,
    List<int>? years,
    bool? enableUserData,
    int? imageTypeLimit,
    List<ImageType>? enableImageTypes,
    String? person,
    List<String>? personIds,
    List<String>? personTypes,
    List<String>? studios,
    List<String>? studioIds,
    String? userId,
    String? nameStartsWithOrGreater,
    String? nameStartsWith,
    String? nameLessThan,
    List<ItemSortBy>? sortBy,
    List<SortOrder>? sortOrder,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'enableImages': enableImages,
      r'enableTotalRecordCount': enableTotalRecordCount,
      r'minCommunityRating': minCommunityRating,
      r'startIndex': startIndex,
      r'limit': limit,
      r'searchTerm': searchTerm,
      r'parentId': parentId,
      r'fields': fields,
      r'excludeItemTypes': excludeItemTypes,
      r'includeItemTypes': includeItemTypes,
      r'filters': filters,
      r'isFavorite': isFavorite,
      r'mediaTypes': mediaTypes,
      r'genres': genres,
      r'genreIds': genreIds,
      r'officialRatings': officialRatings,
      r'tags': tags,
      r'years': years,
      r'enableUserData': enableUserData,
      r'imageTypeLimit': imageTypeLimit,
      r'enableImageTypes': enableImageTypes,
      r'person': person,
      r'personIds': personIds,
      r'personTypes': personTypes,
      r'studios': studios,
      r'studioIds': studioIds,
      r'userId': userId,
      r'nameStartsWithOrGreater': nameStartsWithOrGreater,
      r'nameStartsWith': nameStartsWith,
      r'nameLessThan': nameLessThan,
      r'sortBy': sortBy,
      r'sortOrder': sortOrder,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<BaseItemDtoQueryResult>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/Artists',
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

  @override
  Future<BaseItemDto> getArtistByName({
    required String name,
    String? userId,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{r'userId': userId};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<BaseItemDto>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/Artists/${name}',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late BaseItemDto _value;
    try {
      _value = BaseItemDto.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<BaseItemDtoQueryResult> getAlbumArtists({
    bool? enableImages = true,
    bool? enableTotalRecordCount = true,
    double? minCommunityRating,
    int? startIndex,
    int? limit,
    String? searchTerm,
    String? parentId,
    List<ItemFields>? fields,
    List<BaseItemKind>? excludeItemTypes,
    List<BaseItemKind>? includeItemTypes,
    List<ItemFilter>? filters,
    bool? isFavorite,
    List<MediaType>? mediaTypes,
    List<String>? genres,
    List<String>? genreIds,
    List<String>? officialRatings,
    List<String>? tags,
    List<int>? years,
    bool? enableUserData,
    int? imageTypeLimit,
    List<ImageType>? enableImageTypes,
    String? person,
    List<String>? personIds,
    List<String>? personTypes,
    List<String>? studios,
    List<String>? studioIds,
    String? userId,
    String? nameStartsWithOrGreater,
    String? nameStartsWith,
    String? nameLessThan,
    List<ItemSortBy>? sortBy,
    List<SortOrder>? sortOrder,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'enableImages': enableImages,
      r'enableTotalRecordCount': enableTotalRecordCount,
      r'minCommunityRating': minCommunityRating,
      r'startIndex': startIndex,
      r'limit': limit,
      r'searchTerm': searchTerm,
      r'parentId': parentId,
      r'fields': fields,
      r'excludeItemTypes': excludeItemTypes,
      r'includeItemTypes': includeItemTypes,
      r'filters': filters,
      r'isFavorite': isFavorite,
      r'mediaTypes': mediaTypes,
      r'genres': genres,
      r'genreIds': genreIds,
      r'officialRatings': officialRatings,
      r'tags': tags,
      r'years': years,
      r'enableUserData': enableUserData,
      r'imageTypeLimit': imageTypeLimit,
      r'enableImageTypes': enableImageTypes,
      r'person': person,
      r'personIds': personIds,
      r'personTypes': personTypes,
      r'studios': studios,
      r'studioIds': studioIds,
      r'userId': userId,
      r'nameStartsWithOrGreater': nameStartsWithOrGreater,
      r'nameStartsWith': nameStartsWith,
      r'nameLessThan': nameLessThan,
      r'sortBy': sortBy,
      r'sortOrder': sortOrder,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<BaseItemDtoQueryResult>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/Artists/AlbumArtists',
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
