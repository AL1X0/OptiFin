// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_info_client.dart';

// dart format off

// **************************************************************************
// RetrofitGenerator
// **************************************************************************

// ignore_for_file: type=lint
// ignore_for_file: unnecessary_brace_in_string_interps,no_leading_underscores_for_local_identifiers,unused_element,unnecessary_string_interpolations,unused_element_parameter,avoid_unused_constructor_parameters,unreachable_from_main,avoid_redundant_argument_values

class _MediaInfoClient implements MediaInfoClient {
  _MediaInfoClient(this._dio, {this.baseUrl, this.errorLogger});

  final Dio _dio;

  String? baseUrl;

  final ParseErrorLogger? errorLogger;

  @override
  Future<PlaybackInfoResponse> getPlaybackInfo({
    required String itemId,
    String? userId,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{r'userId': userId};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<PlaybackInfoResponse>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/Items/${itemId}/PlaybackInfo',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late PlaybackInfoResponse _value;
    try {
      _value = PlaybackInfoResponse.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<PlaybackInfoResponse> getPostedPlaybackInfo({
    required String itemId,
    String? userId,
    int? maxStreamingBitrate,
    int? startTimeTicks,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    int? maxAudioChannels,
    String? mediaSourceId,
    String? liveStreamId,
    bool? autoOpenLiveStream,
    bool? enableDirectPlay,
    bool? enableDirectStream,
    bool? enableTranscoding,
    bool? allowVideoStreamCopy,
    bool? allowAudioStreamCopy,
    PlaybackInfoDto? body,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'userId': userId,
      r'maxStreamingBitrate': maxStreamingBitrate,
      r'startTimeTicks': startTimeTicks,
      r'audioStreamIndex': audioStreamIndex,
      r'subtitleStreamIndex': subtitleStreamIndex,
      r'maxAudioChannels': maxAudioChannels,
      r'mediaSourceId': mediaSourceId,
      r'liveStreamId': liveStreamId,
      r'autoOpenLiveStream': autoOpenLiveStream,
      r'enableDirectPlay': enableDirectPlay,
      r'enableDirectStream': enableDirectStream,
      r'enableTranscoding': enableTranscoding,
      r'allowVideoStreamCopy': allowVideoStreamCopy,
      r'allowAudioStreamCopy': allowAudioStreamCopy,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    final _data = <String, dynamic>{};
    _data.addAll(body?.toJson() ?? <String, dynamic>{});
    final _options = _setStreamType<PlaybackInfoResponse>(
      Options(method: 'POST', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/Items/${itemId}/PlaybackInfo',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late PlaybackInfoResponse _value;
    try {
      _value = PlaybackInfoResponse.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<void> closeLiveStream({required String liveStreamId}) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{r'liveStreamId': liveStreamId};
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<void>(
      Options(method: 'POST', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/LiveStreams/Close',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    await _dio.fetch<void>(_options);
  }

  @override
  Future<LiveStreamResponse> openLiveStream({
    String? openToken,
    String? userId,
    String? playSessionId,
    int? maxStreamingBitrate,
    int? startTimeTicks,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    int? maxAudioChannels,
    String? itemId,
    bool? enableDirectPlay,
    bool? enableDirectStream,
    bool? alwaysBurnInSubtitleWhenTranscoding,
    OpenLiveStreamDto? body,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'openToken': openToken,
      r'userId': userId,
      r'playSessionId': playSessionId,
      r'maxStreamingBitrate': maxStreamingBitrate,
      r'startTimeTicks': startTimeTicks,
      r'audioStreamIndex': audioStreamIndex,
      r'subtitleStreamIndex': subtitleStreamIndex,
      r'maxAudioChannels': maxAudioChannels,
      r'itemId': itemId,
      r'enableDirectPlay': enableDirectPlay,
      r'enableDirectStream': enableDirectStream,
      r'alwaysBurnInSubtitleWhenTranscoding':
          alwaysBurnInSubtitleWhenTranscoding,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    final _data = <String, dynamic>{};
    _data.addAll(body?.toJson() ?? <String, dynamic>{});
    final _options = _setStreamType<LiveStreamResponse>(
      Options(method: 'POST', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/LiveStreams/Open',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late LiveStreamResponse _value;
    try {
      _value = LiveStreamResponse.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Stream<String> getBitrateTestBytes({int? size = 102400}) async* {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{r'size': size};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<String>(
      Options(
            method: 'GET',
            headers: _headers,
            extra: _extra,
            responseType: ResponseType.stream,
          )
          .compose(
            _dio.options,
            '/Playback/BitrateTest',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = _dio.fetch<ResponseBody>(_options);
    final _value = _result.asStream().asyncExpand(
      (response) => utf8.decoder.bind(response.data!.stream),
    );
    yield* _value;
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
