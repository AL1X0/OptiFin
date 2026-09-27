// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_client.dart';

// dart format off

// **************************************************************************
// RetrofitGenerator
// **************************************************************************

// ignore_for_file: type=lint
// ignore_for_file: unnecessary_brace_in_string_interps,no_leading_underscores_for_local_identifiers,unused_element,unnecessary_string_interpolations,unused_element_parameter,avoid_unused_constructor_parameters,unreachable_from_main,avoid_redundant_argument_values

class _AudioClient implements AudioClient {
  _AudioClient(this._dio, {this.baseUrl, this.errorLogger});

  final Dio _dio;

  String? baseUrl;

  final ParseErrorLogger? errorLogger;

  @override
  Stream<String> getAudioStream({
    required String itemId,
    int? audioSampleRate,
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
    String? container,
    int? maxAudioBitDepth,
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
    int? videoBitRate,
    int? subtitleStreamIndex,
    SubtitleMethod? subtitleMethod,
    Map<String, String?>? streamOptions,
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
    int? maxRefFrames,
    bool? enableAudioVbrEncoding = true,
  }) async* {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'audioSampleRate': audioSampleRate,
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
      r'container': container,
      r'maxAudioBitDepth': maxAudioBitDepth,
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
      r'videoBitRate': videoBitRate,
      r'subtitleStreamIndex': subtitleStreamIndex,
      r'subtitleMethod': subtitleMethod?.toJson(),
      r'streamOptions': streamOptions,
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
      r'maxRefFrames': maxRefFrames,
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
            '/Audio/${itemId}/stream',
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
  Stream<String> headAudioStream({
    required String itemId,
    int? audioSampleRate,
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
    String? container,
    int? maxAudioBitDepth,
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
    int? videoBitRate,
    int? subtitleStreamIndex,
    SubtitleMethod? subtitleMethod,
    Map<String, String?>? streamOptions,
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
    int? maxRefFrames,
    bool? enableAudioVbrEncoding = true,
  }) async* {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'audioSampleRate': audioSampleRate,
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
      r'container': container,
      r'maxAudioBitDepth': maxAudioBitDepth,
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
      r'videoBitRate': videoBitRate,
      r'subtitleStreamIndex': subtitleStreamIndex,
      r'subtitleMethod': subtitleMethod?.toJson(),
      r'streamOptions': streamOptions,
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
      r'maxRefFrames': maxRefFrames,
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
            '/Audio/${itemId}/stream',
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
  Stream<String> getAudioStreamByContainer({
    required String itemId,
    required String container,
    int? audioSampleRate,
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
    bool? staticValue,
    int? maxAudioBitDepth,
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
    int? videoBitRate,
    int? subtitleStreamIndex,
    SubtitleMethod? subtitleMethod,
    Map<String, String?>? streamOptions,
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
    int? maxRefFrames,
    bool? enableAudioVbrEncoding = true,
  }) async* {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'audioSampleRate': audioSampleRate,
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
      r'static': staticValue,
      r'maxAudioBitDepth': maxAudioBitDepth,
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
      r'videoBitRate': videoBitRate,
      r'subtitleStreamIndex': subtitleStreamIndex,
      r'subtitleMethod': subtitleMethod?.toJson(),
      r'streamOptions': streamOptions,
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
      r'maxRefFrames': maxRefFrames,
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
            '/Audio/${itemId}/stream.${container}',
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
  Stream<String> headAudioStreamByContainer({
    required String itemId,
    required String container,
    int? audioSampleRate,
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
    bool? staticValue,
    int? maxAudioBitDepth,
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
    int? videoBitRate,
    int? subtitleStreamIndex,
    SubtitleMethod? subtitleMethod,
    Map<String, String?>? streamOptions,
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
    int? maxRefFrames,
    bool? enableAudioVbrEncoding = true,
  }) async* {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'audioSampleRate': audioSampleRate,
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
      r'static': staticValue,
      r'maxAudioBitDepth': maxAudioBitDepth,
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
      r'videoBitRate': videoBitRate,
      r'subtitleStreamIndex': subtitleStreamIndex,
      r'subtitleMethod': subtitleMethod?.toJson(),
      r'streamOptions': streamOptions,
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
      r'maxRefFrames': maxRefFrames,
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
            '/Audio/${itemId}/stream.${container}',
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
  Stream<String> getUniversalAudioStream({
    required String itemId,
    bool? enableAudioVbrEncoding = true,
    bool? enableRedirection = true,
    List<String>? container,
    String? mediaSourceId,
    String? deviceId,
    String? userId,
    String? audioCodec,
    int? maxAudioChannels,
    int? transcodingAudioChannels,
    int? maxStreamingBitrate,
    int? audioBitRate,
    int? startTimeTicks,
    String? transcodingContainer,
    TranscodingProtocol? transcodingProtocol,
    int? maxAudioSampleRate,
    int? maxAudioBitDepth,
    bool? enableRemoteMedia,
  }) async* {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'enableAudioVbrEncoding': enableAudioVbrEncoding,
      r'enableRedirection': enableRedirection,
      r'container': container,
      r'mediaSourceId': mediaSourceId,
      r'deviceId': deviceId,
      r'userId': userId,
      r'audioCodec': audioCodec,
      r'maxAudioChannels': maxAudioChannels,
      r'transcodingAudioChannels': transcodingAudioChannels,
      r'maxStreamingBitrate': maxStreamingBitrate,
      r'audioBitRate': audioBitRate,
      r'startTimeTicks': startTimeTicks,
      r'transcodingContainer': transcodingContainer,
      r'transcodingProtocol': transcodingProtocol?.toJson(),
      r'maxAudioSampleRate': maxAudioSampleRate,
      r'maxAudioBitDepth': maxAudioBitDepth,
      r'enableRemoteMedia': enableRemoteMedia,
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
            '/Audio/${itemId}/universal',
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
  Stream<String> headUniversalAudioStream({
    required String itemId,
    bool? enableAudioVbrEncoding = true,
    bool? enableRedirection = true,
    List<String>? container,
    String? mediaSourceId,
    String? deviceId,
    String? userId,
    String? audioCodec,
    int? maxAudioChannels,
    int? transcodingAudioChannels,
    int? maxStreamingBitrate,
    int? audioBitRate,
    int? startTimeTicks,
    String? transcodingContainer,
    TranscodingProtocol? transcodingProtocol,
    int? maxAudioSampleRate,
    int? maxAudioBitDepth,
    bool? enableRemoteMedia,
  }) async* {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'enableAudioVbrEncoding': enableAudioVbrEncoding,
      r'enableRedirection': enableRedirection,
      r'container': container,
      r'mediaSourceId': mediaSourceId,
      r'deviceId': deviceId,
      r'userId': userId,
      r'audioCodec': audioCodec,
      r'maxAudioChannels': maxAudioChannels,
      r'transcodingAudioChannels': transcodingAudioChannels,
      r'maxStreamingBitrate': maxStreamingBitrate,
      r'audioBitRate': audioBitRate,
      r'startTimeTicks': startTimeTicks,
      r'transcodingContainer': transcodingContainer,
      r'transcodingProtocol': transcodingProtocol?.toJson(),
      r'maxAudioSampleRate': maxAudioSampleRate,
      r'maxAudioBitDepth': maxAudioBitDepth,
      r'enableRemoteMedia': enableRemoteMedia,
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
            '/Audio/${itemId}/universal',
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
