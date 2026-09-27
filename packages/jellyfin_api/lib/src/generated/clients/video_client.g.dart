// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_client.dart';

// dart format off

// **************************************************************************
// RetrofitGenerator
// **************************************************************************

// ignore_for_file: type=lint
// ignore_for_file: unnecessary_brace_in_string_interps,no_leading_underscores_for_local_identifiers,unused_element,unnecessary_string_interpolations,unused_element_parameter,avoid_unused_constructor_parameters,unreachable_from_main,avoid_redundant_argument_values

class _VideoClient implements VideoClient {
  _VideoClient(this._dio, {this.baseUrl, this.errorLogger});

  final Dio _dio;

  String? baseUrl;

  final ParseErrorLogger? errorLogger;

  @override
  Stream<String> getAttachment({
    required String videoId,
    required String mediaSourceId,
    required int index,
  }) async* {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{};
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
            '/Videos/${videoId}/${mediaSourceId}/Attachments/${index}',
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

  @override
  Future<BaseItemDtoQueryResult> getAdditionalPart({
    required String itemId,
    String? userId,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{r'userId': userId};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<BaseItemDtoQueryResult>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/Videos/${itemId}/AdditionalParts',
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
  Future<void> deleteAlternateSources({required String itemId}) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{};
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<void>(
      Options(method: 'DELETE', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/Videos/${itemId}/AlternateSources',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    await _dio.fetch<void>(_options);
  }

  @override
  Stream<String> getVideoStream({
    required String itemId,
    int? maxAudioBitDepth,
    bool? staticValue,
    String? params,
    String? tag,
    String? deviceProfileId,
    String? playSessionId,
    String? segmentContainer,
    int? segmentLength,
    int? minSegments,
    String? mediaSourceId,
    String? deviceId,
    String? audioCodec,
    bool? enableAutoStreamCopy,
    bool? allowVideoStreamCopy,
    bool? allowAudioStreamCopy,
    int? audioSampleRate,
    String? container,
    int? audioBitRate,
    int? audioChannels,
    int? maxAudioChannels,
    String? profile,
    String? level,
    double? framerate,
    double? maxFramerate,
    bool? copyTimestamps,
    int? startTimeTicks,
    int? width,
    int? height,
    int? maxWidth,
    int? maxHeight,
    int? videoBitRate,
    int? subtitleStreamIndex,
    Map<String, String?>? streamOptions,
    int? maxRefFrames,
    int? maxVideoBitDepth,
    bool? requireAvc,
    bool? deInterlace,
    bool? requireNonAnamorphic,
    int? transcodingMaxAudioChannels,
    int? cpuCoreLimit,
    String? liveStreamId,
    bool? enableMpegtsM2TsMode,
    String? videoCodec,
    String? subtitleCodec,
    String? transcodeReasons,
    int? audioStreamIndex,
    int? videoStreamIndex,
    Context? context,
    SubtitleMethod? subtitleMethod,
    bool? enableAudioVbrEncoding = true,
  }) async* {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'maxAudioBitDepth': maxAudioBitDepth,
      r'static': staticValue,
      r'params': params,
      r'tag': tag,
      r'deviceProfileId': deviceProfileId,
      r'playSessionId': playSessionId,
      r'segmentContainer': segmentContainer,
      r'segmentLength': segmentLength,
      r'minSegments': minSegments,
      r'mediaSourceId': mediaSourceId,
      r'deviceId': deviceId,
      r'audioCodec': audioCodec,
      r'enableAutoStreamCopy': enableAutoStreamCopy,
      r'allowVideoStreamCopy': allowVideoStreamCopy,
      r'allowAudioStreamCopy': allowAudioStreamCopy,
      r'audioSampleRate': audioSampleRate,
      r'container': container,
      r'audioBitRate': audioBitRate,
      r'audioChannels': audioChannels,
      r'maxAudioChannels': maxAudioChannels,
      r'profile': profile,
      r'level': level,
      r'framerate': framerate,
      r'maxFramerate': maxFramerate,
      r'copyTimestamps': copyTimestamps,
      r'startTimeTicks': startTimeTicks,
      r'width': width,
      r'height': height,
      r'maxWidth': maxWidth,
      r'maxHeight': maxHeight,
      r'videoBitRate': videoBitRate,
      r'subtitleStreamIndex': subtitleStreamIndex,
      r'streamOptions': streamOptions,
      r'maxRefFrames': maxRefFrames,
      r'maxVideoBitDepth': maxVideoBitDepth,
      r'requireAvc': requireAvc,
      r'deInterlace': deInterlace,
      r'requireNonAnamorphic': requireNonAnamorphic,
      r'transcodingMaxAudioChannels': transcodingMaxAudioChannels,
      r'cpuCoreLimit': cpuCoreLimit,
      r'liveStreamId': liveStreamId,
      r'enableMpegtsM2TsMode': enableMpegtsM2TsMode,
      r'videoCodec': videoCodec,
      r'subtitleCodec': subtitleCodec,
      r'transcodeReasons': transcodeReasons,
      r'audioStreamIndex': audioStreamIndex,
      r'videoStreamIndex': videoStreamIndex,
      r'context': context?.toJson(),
      r'subtitleMethod': subtitleMethod?.toJson(),
      r'enableAudioVbrEncoding': enableAudioVbrEncoding,
    };
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
            '/Videos/${itemId}/stream',
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

  @override
  Stream<String> headVideoStream({
    required String itemId,
    int? maxAudioBitDepth,
    bool? staticValue,
    String? params,
    String? tag,
    String? deviceProfileId,
    String? playSessionId,
    String? segmentContainer,
    int? segmentLength,
    int? minSegments,
    String? mediaSourceId,
    String? deviceId,
    String? audioCodec,
    bool? enableAutoStreamCopy,
    bool? allowVideoStreamCopy,
    bool? allowAudioStreamCopy,
    int? audioSampleRate,
    String? container,
    int? audioBitRate,
    int? audioChannels,
    int? maxAudioChannels,
    String? profile,
    String? level,
    double? framerate,
    double? maxFramerate,
    bool? copyTimestamps,
    int? startTimeTicks,
    int? width,
    int? height,
    int? maxWidth,
    int? maxHeight,
    int? videoBitRate,
    int? subtitleStreamIndex,
    Map<String, String?>? streamOptions,
    int? maxRefFrames,
    int? maxVideoBitDepth,
    bool? requireAvc,
    bool? deInterlace,
    bool? requireNonAnamorphic,
    int? transcodingMaxAudioChannels,
    int? cpuCoreLimit,
    String? liveStreamId,
    bool? enableMpegtsM2TsMode,
    String? videoCodec,
    String? subtitleCodec,
    String? transcodeReasons,
    int? audioStreamIndex,
    int? videoStreamIndex,
    Context? context,
    SubtitleMethod? subtitleMethod,
    bool? enableAudioVbrEncoding = true,
  }) async* {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'maxAudioBitDepth': maxAudioBitDepth,
      r'static': staticValue,
      r'params': params,
      r'tag': tag,
      r'deviceProfileId': deviceProfileId,
      r'playSessionId': playSessionId,
      r'segmentContainer': segmentContainer,
      r'segmentLength': segmentLength,
      r'minSegments': minSegments,
      r'mediaSourceId': mediaSourceId,
      r'deviceId': deviceId,
      r'audioCodec': audioCodec,
      r'enableAutoStreamCopy': enableAutoStreamCopy,
      r'allowVideoStreamCopy': allowVideoStreamCopy,
      r'allowAudioStreamCopy': allowAudioStreamCopy,
      r'audioSampleRate': audioSampleRate,
      r'container': container,
      r'audioBitRate': audioBitRate,
      r'audioChannels': audioChannels,
      r'maxAudioChannels': maxAudioChannels,
      r'profile': profile,
      r'level': level,
      r'framerate': framerate,
      r'maxFramerate': maxFramerate,
      r'copyTimestamps': copyTimestamps,
      r'startTimeTicks': startTimeTicks,
      r'width': width,
      r'height': height,
      r'maxWidth': maxWidth,
      r'maxHeight': maxHeight,
      r'videoBitRate': videoBitRate,
      r'subtitleStreamIndex': subtitleStreamIndex,
      r'streamOptions': streamOptions,
      r'maxRefFrames': maxRefFrames,
      r'maxVideoBitDepth': maxVideoBitDepth,
      r'requireAvc': requireAvc,
      r'deInterlace': deInterlace,
      r'requireNonAnamorphic': requireNonAnamorphic,
      r'transcodingMaxAudioChannels': transcodingMaxAudioChannels,
      r'cpuCoreLimit': cpuCoreLimit,
      r'liveStreamId': liveStreamId,
      r'enableMpegtsM2TsMode': enableMpegtsM2TsMode,
      r'videoCodec': videoCodec,
      r'subtitleCodec': subtitleCodec,
      r'transcodeReasons': transcodeReasons,
      r'audioStreamIndex': audioStreamIndex,
      r'videoStreamIndex': videoStreamIndex,
      r'context': context?.toJson(),
      r'subtitleMethod': subtitleMethod?.toJson(),
      r'enableAudioVbrEncoding': enableAudioVbrEncoding,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<String>(
      Options(
            method: 'HEAD',
            headers: _headers,
            extra: _extra,
            responseType: ResponseType.stream,
          )
          .compose(
            _dio.options,
            '/Videos/${itemId}/stream',
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

  @override
  Stream<String> getVideoStreamByContainer({
    required String itemId,
    required String container,
    int? maxAudioBitDepth,
    String? params,
    String? tag,
    String? deviceProfileId,
    String? playSessionId,
    String? segmentContainer,
    int? segmentLength,
    int? minSegments,
    String? mediaSourceId,
    String? deviceId,
    String? audioCodec,
    bool? enableAutoStreamCopy,
    bool? allowVideoStreamCopy,
    bool? allowAudioStreamCopy,
    int? audioSampleRate,
    bool? staticValue,
    int? audioBitRate,
    int? audioChannels,
    int? maxAudioChannels,
    String? profile,
    String? level,
    double? framerate,
    double? maxFramerate,
    bool? copyTimestamps,
    int? startTimeTicks,
    int? width,
    int? height,
    int? maxWidth,
    int? maxHeight,
    int? videoBitRate,
    int? subtitleStreamIndex,
    Map<String, String?>? streamOptions,
    int? maxRefFrames,
    int? maxVideoBitDepth,
    bool? requireAvc,
    bool? deInterlace,
    bool? requireNonAnamorphic,
    int? transcodingMaxAudioChannels,
    int? cpuCoreLimit,
    String? liveStreamId,
    bool? enableMpegtsM2TsMode,
    String? videoCodec,
    String? subtitleCodec,
    String? transcodeReasons,
    int? audioStreamIndex,
    int? videoStreamIndex,
    Context? context,
    SubtitleMethod? subtitleMethod,
    bool? enableAudioVbrEncoding = true,
  }) async* {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'maxAudioBitDepth': maxAudioBitDepth,
      r'params': params,
      r'tag': tag,
      r'deviceProfileId': deviceProfileId,
      r'playSessionId': playSessionId,
      r'segmentContainer': segmentContainer,
      r'segmentLength': segmentLength,
      r'minSegments': minSegments,
      r'mediaSourceId': mediaSourceId,
      r'deviceId': deviceId,
      r'audioCodec': audioCodec,
      r'enableAutoStreamCopy': enableAutoStreamCopy,
      r'allowVideoStreamCopy': allowVideoStreamCopy,
      r'allowAudioStreamCopy': allowAudioStreamCopy,
      r'audioSampleRate': audioSampleRate,
      r'static': staticValue,
      r'audioBitRate': audioBitRate,
      r'audioChannels': audioChannels,
      r'maxAudioChannels': maxAudioChannels,
      r'profile': profile,
      r'level': level,
      r'framerate': framerate,
      r'maxFramerate': maxFramerate,
      r'copyTimestamps': copyTimestamps,
      r'startTimeTicks': startTimeTicks,
      r'width': width,
      r'height': height,
      r'maxWidth': maxWidth,
      r'maxHeight': maxHeight,
      r'videoBitRate': videoBitRate,
      r'subtitleStreamIndex': subtitleStreamIndex,
      r'streamOptions': streamOptions,
      r'maxRefFrames': maxRefFrames,
      r'maxVideoBitDepth': maxVideoBitDepth,
      r'requireAvc': requireAvc,
      r'deInterlace': deInterlace,
      r'requireNonAnamorphic': requireNonAnamorphic,
      r'transcodingMaxAudioChannels': transcodingMaxAudioChannels,
      r'cpuCoreLimit': cpuCoreLimit,
      r'liveStreamId': liveStreamId,
      r'enableMpegtsM2TsMode': enableMpegtsM2TsMode,
      r'videoCodec': videoCodec,
      r'subtitleCodec': subtitleCodec,
      r'transcodeReasons': transcodeReasons,
      r'audioStreamIndex': audioStreamIndex,
      r'videoStreamIndex': videoStreamIndex,
      r'context': context?.toJson(),
      r'subtitleMethod': subtitleMethod?.toJson(),
      r'enableAudioVbrEncoding': enableAudioVbrEncoding,
    };
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
            '/Videos/${itemId}/stream.${container}',
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

  @override
  Stream<String> headVideoStreamByContainer({
    required String itemId,
    required String container,
    int? maxAudioBitDepth,
    String? params,
    String? tag,
    String? deviceProfileId,
    String? playSessionId,
    String? segmentContainer,
    int? segmentLength,
    int? minSegments,
    String? mediaSourceId,
    String? deviceId,
    String? audioCodec,
    bool? enableAutoStreamCopy,
    bool? allowVideoStreamCopy,
    bool? allowAudioStreamCopy,
    int? audioSampleRate,
    bool? staticValue,
    int? audioBitRate,
    int? audioChannels,
    int? maxAudioChannels,
    String? profile,
    String? level,
    double? framerate,
    double? maxFramerate,
    bool? copyTimestamps,
    int? startTimeTicks,
    int? width,
    int? height,
    int? maxWidth,
    int? maxHeight,
    int? videoBitRate,
    int? subtitleStreamIndex,
    Map<String, String?>? streamOptions,
    int? maxRefFrames,
    int? maxVideoBitDepth,
    bool? requireAvc,
    bool? deInterlace,
    bool? requireNonAnamorphic,
    int? transcodingMaxAudioChannels,
    int? cpuCoreLimit,
    String? liveStreamId,
    bool? enableMpegtsM2TsMode,
    String? videoCodec,
    String? subtitleCodec,
    String? transcodeReasons,
    int? audioStreamIndex,
    int? videoStreamIndex,
    Context? context,
    SubtitleMethod? subtitleMethod,
    bool? enableAudioVbrEncoding = true,
  }) async* {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'maxAudioBitDepth': maxAudioBitDepth,
      r'params': params,
      r'tag': tag,
      r'deviceProfileId': deviceProfileId,
      r'playSessionId': playSessionId,
      r'segmentContainer': segmentContainer,
      r'segmentLength': segmentLength,
      r'minSegments': minSegments,
      r'mediaSourceId': mediaSourceId,
      r'deviceId': deviceId,
      r'audioCodec': audioCodec,
      r'enableAutoStreamCopy': enableAutoStreamCopy,
      r'allowVideoStreamCopy': allowVideoStreamCopy,
      r'allowAudioStreamCopy': allowAudioStreamCopy,
      r'audioSampleRate': audioSampleRate,
      r'static': staticValue,
      r'audioBitRate': audioBitRate,
      r'audioChannels': audioChannels,
      r'maxAudioChannels': maxAudioChannels,
      r'profile': profile,
      r'level': level,
      r'framerate': framerate,
      r'maxFramerate': maxFramerate,
      r'copyTimestamps': copyTimestamps,
      r'startTimeTicks': startTimeTicks,
      r'width': width,
      r'height': height,
      r'maxWidth': maxWidth,
      r'maxHeight': maxHeight,
      r'videoBitRate': videoBitRate,
      r'subtitleStreamIndex': subtitleStreamIndex,
      r'streamOptions': streamOptions,
      r'maxRefFrames': maxRefFrames,
      r'maxVideoBitDepth': maxVideoBitDepth,
      r'requireAvc': requireAvc,
      r'deInterlace': deInterlace,
      r'requireNonAnamorphic': requireNonAnamorphic,
      r'transcodingMaxAudioChannels': transcodingMaxAudioChannels,
      r'cpuCoreLimit': cpuCoreLimit,
      r'liveStreamId': liveStreamId,
      r'enableMpegtsM2TsMode': enableMpegtsM2TsMode,
      r'videoCodec': videoCodec,
      r'subtitleCodec': subtitleCodec,
      r'transcodeReasons': transcodeReasons,
      r'audioStreamIndex': audioStreamIndex,
      r'videoStreamIndex': videoStreamIndex,
      r'context': context?.toJson(),
      r'subtitleMethod': subtitleMethod?.toJson(),
      r'enableAudioVbrEncoding': enableAudioVbrEncoding,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<String>(
      Options(
            method: 'HEAD',
            headers: _headers,
            extra: _extra,
            responseType: ResponseType.stream,
          )
          .compose(
            _dio.options,
            '/Videos/${itemId}/stream.${container}',
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

  @override
  Future<void> mergeVersions({required List<String> ids}) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{r'ids': ids};
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<void>(
      Options(method: 'POST', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/Videos/MergeVersions',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    await _dio.fetch<void>(_options);
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
