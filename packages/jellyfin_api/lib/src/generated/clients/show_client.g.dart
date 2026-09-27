// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'show_client.dart';

// dart format off

// **************************************************************************
// RetrofitGenerator
// **************************************************************************

// ignore_for_file: type=lint
// ignore_for_file: unnecessary_brace_in_string_interps,no_leading_underscores_for_local_identifiers,unused_element,unnecessary_string_interpolations,unused_element_parameter,avoid_unused_constructor_parameters,unreachable_from_main,avoid_redundant_argument_values

class _ShowClient implements ShowClient {
  _ShowClient(this._dio, {this.baseUrl, this.errorLogger});

  final Dio _dio;

  String? baseUrl;

  final ParseErrorLogger? errorLogger;

  @override
  Future<BaseItemDtoQueryResult> getEpisodes({
    required String seriesId,
    String? userId,
    List<ItemFields>? fields,
    int? season,
    String? seasonId,
    bool? isMissing,
    String? adjacentTo,
    String? startItemId,
    int? startIndex,
    int? limit,
    bool? enableImages,
    int? imageTypeLimit,
    List<ImageType>? enableImageTypes,
    bool? enableUserData,
    SortBy? sortBy,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'userId': userId,
      r'fields': fields,
      r'season': season,
      r'seasonId': seasonId,
      r'isMissing': isMissing,
      r'adjacentTo': adjacentTo,
      r'startItemId': startItemId,
      r'startIndex': startIndex,
      r'limit': limit,
      r'enableImages': enableImages,
      r'imageTypeLimit': imageTypeLimit,
      r'enableImageTypes': enableImageTypes,
      r'enableUserData': enableUserData,
      r'sortBy': sortBy?.toJson(),
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<BaseItemDtoQueryResult>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/Shows/${seriesId}/Episodes',
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
  Future<BaseItemDtoQueryResult> getSeasons({
    required String seriesId,
    String? userId,
    List<ItemFields>? fields,
    bool? isSpecialSeason,
    bool? isMissing,
    String? adjacentTo,
    bool? enableImages,
    int? imageTypeLimit,
    List<ImageType>? enableImageTypes,
    bool? enableUserData,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'userId': userId,
      r'fields': fields,
      r'isSpecialSeason': isSpecialSeason,
      r'isMissing': isMissing,
      r'adjacentTo': adjacentTo,
      r'enableImages': enableImages,
      r'imageTypeLimit': imageTypeLimit,
      r'enableImageTypes': enableImageTypes,
      r'enableUserData': enableUserData,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<BaseItemDtoQueryResult>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/Shows/${seriesId}/Seasons',
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
  Future<BaseItemDtoQueryResult> getNextUp({
    bool? enableTotalRecordCount = true,
    bool? enableResumable = true,
    bool? enableRewatching = false,
    String? userId,
    int? startIndex,
    int? limit,
    List<ItemFields>? fields,
    String? seriesId,
    String? parentId,
    bool? enableImages,
    int? imageTypeLimit,
    List<ImageType>? enableImageTypes,
    bool? enableUserData,
    DateTime? nextUpDateCutoff,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'enableTotalRecordCount': enableTotalRecordCount,
      r'enableResumable': enableResumable,
      r'enableRewatching': enableRewatching,
      r'userId': userId,
      r'startIndex': startIndex,
      r'limit': limit,
      r'fields': fields,
      r'seriesId': seriesId,
      r'parentId': parentId,
      r'enableImages': enableImages,
      r'imageTypeLimit': imageTypeLimit,
      r'enableImageTypes': enableImageTypes,
      r'enableUserData': enableUserData,
      r'nextUpDateCutoff': nextUpDateCutoff?.toIso8601String(),
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<BaseItemDtoQueryResult>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/Shows/NextUp',
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
  Future<BaseItemDtoQueryResult> getUpcomingEpisodes({
    String? userId,
    int? startIndex,
    int? limit,
    List<ItemFields>? fields,
    String? parentId,
    bool? enableImages,
    int? imageTypeLimit,
    List<ImageType>? enableImageTypes,
    bool? enableUserData,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'userId': userId,
      r'startIndex': startIndex,
      r'limit': limit,
      r'fields': fields,
      r'parentId': parentId,
      r'enableImages': enableImages,
      r'imageTypeLimit': imageTypeLimit,
      r'enableImageTypes': enableImageTypes,
      r'enableUserData': enableUserData,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<BaseItemDtoQueryResult>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/Shows/Upcoming',
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
