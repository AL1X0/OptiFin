// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_client.dart';

// dart format off

// **************************************************************************
// RetrofitGenerator
// **************************************************************************

// ignore_for_file: type=lint
// ignore_for_file: unnecessary_brace_in_string_interps,no_leading_underscores_for_local_identifiers,unused_element,unnecessary_string_interpolations,unused_element_parameter,avoid_unused_constructor_parameters,unreachable_from_main,avoid_redundant_argument_values

class _SearchClient implements SearchClient {
  _SearchClient(this._dio, {this.baseUrl, this.errorLogger});

  final Dio _dio;

  String? baseUrl;

  final ParseErrorLogger? errorLogger;

  @override
  Future<SearchHintResult> getSearchHints({
    required String searchTerm,
    bool? includePeople = true,
    bool? includeMedia = true,
    bool? includeGenres = true,
    bool? includeStudios = true,
    bool? includeArtists = true,
    int? startIndex,
    int? limit,
    String? userId,
    List<BaseItemKind>? includeItemTypes,
    List<BaseItemKind>? excludeItemTypes,
    List<MediaType>? mediaTypes,
    String? parentId,
    bool? isMovie,
    bool? isSeries,
    bool? isNews,
    bool? isKids,
    bool? isSports,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'searchTerm': searchTerm,
      r'includePeople': includePeople,
      r'includeMedia': includeMedia,
      r'includeGenres': includeGenres,
      r'includeStudios': includeStudios,
      r'includeArtists': includeArtists,
      r'startIndex': startIndex,
      r'limit': limit,
      r'userId': userId,
      r'includeItemTypes': includeItemTypes,
      r'excludeItemTypes': excludeItemTypes,
      r'mediaTypes': mediaTypes,
      r'parentId': parentId,
      r'isMovie': isMovie,
      r'isSeries': isSeries,
      r'isNews': isNews,
      r'isKids': isKids,
      r'isSports': isSports,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<SearchHintResult>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/Search/Hints',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late SearchHintResult _value;
    try {
      _value = SearchHintResult.fromJson(_result.data!);
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
