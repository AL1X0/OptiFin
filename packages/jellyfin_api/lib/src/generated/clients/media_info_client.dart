// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/live_stream_response.dart';
import '../models/open_live_stream_dto.dart';
import '../models/playback_info_dto.dart';
import '../models/playback_info_response.dart';

part 'media_info_client.g.dart';

@RestApi()
abstract class MediaInfoClient {
  factory MediaInfoClient(Dio dio, {String? baseUrl}) = _MediaInfoClient;

  /// Gets live playback media info for an item.
  ///
  /// [itemId] - The item id.
  ///
  /// [userId] - The user id.
  @GET('/Items/{itemId}/PlaybackInfo')
  Future<PlaybackInfoResponse> getPlaybackInfo({
    @Path('itemId') required String itemId,
    @Query('userId') String? userId,
  });

  /// Gets live playback media info for an item.
  ///
  /// For backwards compatibility parameters can be sent via Query or Body, with Query having higher precedence.
  /// Query parameters are obsolete.
  ///
  /// [itemId] - The item id.
  ///
  /// [userId] - The user id.
  ///
  /// [maxStreamingBitrate] - The maximum streaming bitrate.
  ///
  /// [startTimeTicks] - The start time in ticks.
  ///
  /// [audioStreamIndex] - The audio stream index.
  ///
  /// [subtitleStreamIndex] - The subtitle stream index.
  ///
  /// [maxAudioChannels] - The maximum number of audio channels.
  ///
  /// [mediaSourceId] - The media source id.
  ///
  /// [liveStreamId] - The livestream id.
  ///
  /// [autoOpenLiveStream] - Whether to auto open the livestream.
  ///
  /// [enableDirectPlay] - Whether to enable direct play. Default: true.
  ///
  /// [enableDirectStream] - Whether to enable direct stream. Default: true.
  ///
  /// [enableTranscoding] - Whether to enable transcoding. Default: true.
  ///
  /// [allowVideoStreamCopy] - Whether to allow to copy the video stream. Default: true.
  ///
  /// [allowAudioStreamCopy] - Whether to allow to copy the audio stream. Default: true.
  ///
  /// [body] - Playback info dto.
  @POST('/Items/{itemId}/PlaybackInfo')
  Future<PlaybackInfoResponse> getPostedPlaybackInfo({
    @Path('itemId') required String itemId,
    @Deprecated('This is marked as deprecated')
    @Query('userId') String? userId,
    @Deprecated('This is marked as deprecated')
    @Query('maxStreamingBitrate') int? maxStreamingBitrate,
    @Deprecated('This is marked as deprecated')
    @Query('startTimeTicks') int? startTimeTicks,
    @Deprecated('This is marked as deprecated')
    @Query('audioStreamIndex') int? audioStreamIndex,
    @Deprecated('This is marked as deprecated')
    @Query('subtitleStreamIndex') int? subtitleStreamIndex,
    @Deprecated('This is marked as deprecated')
    @Query('maxAudioChannels') int? maxAudioChannels,
    @Deprecated('This is marked as deprecated')
    @Query('mediaSourceId') String? mediaSourceId,
    @Deprecated('This is marked as deprecated')
    @Query('liveStreamId') String? liveStreamId,
    @Deprecated('This is marked as deprecated')
    @Query('autoOpenLiveStream') bool? autoOpenLiveStream,
    @Deprecated('This is marked as deprecated')
    @Query('enableDirectPlay') bool? enableDirectPlay,
    @Deprecated('This is marked as deprecated')
    @Query('enableDirectStream') bool? enableDirectStream,
    @Deprecated('This is marked as deprecated')
    @Query('enableTranscoding') bool? enableTranscoding,
    @Deprecated('This is marked as deprecated')
    @Query('allowVideoStreamCopy') bool? allowVideoStreamCopy,
    @Deprecated('This is marked as deprecated')
    @Query('allowAudioStreamCopy') bool? allowAudioStreamCopy,
    @Body() PlaybackInfoDto? body,
  });

  /// Closes a media source.
  ///
  /// [liveStreamId] - The livestream id.
  @POST('/LiveStreams/Close')
  Future<void> closeLiveStream({
    @Query('liveStreamId') required String liveStreamId,
  });

  /// Opens a media source.
  ///
  /// [openToken] - The open token.
  ///
  /// [userId] - The user id.
  ///
  /// [playSessionId] - The play session id.
  ///
  /// [maxStreamingBitrate] - The maximum streaming bitrate.
  ///
  /// [startTimeTicks] - The start time in ticks.
  ///
  /// [audioStreamIndex] - The audio stream index.
  ///
  /// [subtitleStreamIndex] - The subtitle stream index.
  ///
  /// [maxAudioChannels] - The maximum number of audio channels.
  ///
  /// [itemId] - The item id.
  ///
  /// [enableDirectPlay] - Whether to enable direct play. Default: true.
  ///
  /// [enableDirectStream] - Whether to enable direct stream. Default: true.
  ///
  /// [alwaysBurnInSubtitleWhenTranscoding] - Always burn-in subtitle when transcoding.
  ///
  /// [body] - Open live stream dto.
  @POST('/LiveStreams/Open')
  Future<LiveStreamResponse> openLiveStream({
    @Query('openToken') String? openToken,
    @Query('userId') String? userId,
    @Query('playSessionId') String? playSessionId,
    @Query('maxStreamingBitrate') int? maxStreamingBitrate,
    @Query('startTimeTicks') int? startTimeTicks,
    @Query('audioStreamIndex') int? audioStreamIndex,
    @Query('subtitleStreamIndex') int? subtitleStreamIndex,
    @Query('maxAudioChannels') int? maxAudioChannels,
    @Query('itemId') String? itemId,
    @Query('enableDirectPlay') bool? enableDirectPlay,
    @Query('enableDirectStream') bool? enableDirectStream,
    @Query('alwaysBurnInSubtitleWhenTranscoding') bool? alwaysBurnInSubtitleWhenTranscoding,
    @Body() OpenLiveStreamDto? body,
  });

  /// Tests the network with a request with the size of the bitrate.
  ///
  /// [size] - The bitrate. Defaults to 102400.
  @GET('/Playback/BitrateTest')
  @DioResponseType(ResponseType.stream)
  Stream<String> getBitrateTestBytes({
    @Query('size') int? size = 102400,
  });
}
