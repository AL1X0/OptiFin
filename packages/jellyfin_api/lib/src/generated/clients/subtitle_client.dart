// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/font_file.dart';
import '../models/remote_subtitle_info.dart';
import '../models/upload_subtitle_dto.dart';

part 'subtitle_client.g.dart';

@RestApi()
abstract class SubtitleClient {
  factory SubtitleClient(Dio dio, {String? baseUrl}) = _SubtitleClient;

  /// Gets a list of available fallback font files.
  @GET('/FallbackFont/Fonts')
  Future<List<FontFile>> getFallbackFontList();

  /// Gets a fallback font file.
  ///
  /// [name] - The name of the fallback font file to get.
  @GET('/FallbackFont/Fonts/{name}')
  @DioResponseType(ResponseType.stream)
  Stream<String> getFallbackFont({
    @Path('name') required String name,
  });

  /// Search remote subtitles.
  ///
  /// [itemId] - The item id.
  ///
  /// [language] - The language of the subtitles.
  ///
  /// [isPerfectMatch] - Optional. Only show subtitles which are a perfect match.
  @GET('/Items/{itemId}/RemoteSearch/Subtitles/{language}')
  Future<List<RemoteSubtitleInfo>> searchRemoteSubtitles({
    @Path('itemId') required String itemId,
    @Path('language') required String language,
    @Query('isPerfectMatch') bool? isPerfectMatch,
  });

  /// Downloads a remote subtitle.
  ///
  /// [itemId] - The item id.
  ///
  /// [subtitleId] - The subtitle id.
  @POST('/Items/{itemId}/RemoteSearch/Subtitles/{subtitleId}')
  Future<void> downloadRemoteSubtitles({
    @Path('itemId') required String itemId,
    @Path('subtitleId') required String subtitleId,
  });

  /// Gets the remote subtitles.
  ///
  /// [subtitleId] - The item id.
  @GET('/Providers/Subtitles/Subtitles/{subtitleId}')
  @DioResponseType(ResponseType.stream)
  Stream<String> getRemoteSubtitles({
    @Path('subtitleId') required String subtitleId,
  });

  /// Gets an HLS subtitle playlist.
  ///
  /// [itemId] - The item id.
  ///
  /// [index] - The subtitle stream index.
  ///
  /// [mediaSourceId] - The media source id.
  ///
  /// [segmentLength] - The subtitle segment length.
  @GET('/Videos/{itemId}/{mediaSourceId}/Subtitles/{index}/subtitles.m3u8')
  @DioResponseType(ResponseType.stream)
  Stream<String> getSubtitlePlaylist({
    @Path('itemId') required String itemId,
    @Path('index') required int index,
    @Path('mediaSourceId') required String mediaSourceId,
    @Query('segmentLength') required int segmentLength,
  });

  /// Upload an external subtitle file.
  ///
  /// [itemId] - The item the subtitle belongs to.
  ///
  /// [body] - Upload subtitles dto.
  @POST('/Videos/{itemId}/Subtitles')
  Future<void> uploadSubtitle({
    @Path('itemId') required String itemId,
    @Body() required UploadSubtitleDto body,
  });

  /// Deletes an external subtitle file.
  ///
  /// [itemId] - The item id.
  ///
  /// [index] - The index of the subtitle file.
  @DELETE('/Videos/{itemId}/Subtitles/{index}')
  Future<void> deleteSubtitle({
    @Path('itemId') required String itemId,
    @Path('index') required int index,
  });

  /// Gets subtitles in a specified format.
  ///
  /// [routeItemId] - The (route) item id.
  ///
  /// [routeMediaSourceId] - The (route) media source id.
  ///
  /// [routeIndex] - The (route) subtitle stream index.
  ///
  /// [routeStartPositionTicks] - The (route) start position of the subtitle in ticks.
  ///
  /// [routeFormat] - The (route) format of the returned subtitle.
  ///
  /// [itemId] - The item id.
  ///
  /// [mediaSourceId] - The media source id.
  ///
  /// [index] - The subtitle stream index.
  ///
  /// [startPositionTicks] - The start position of the subtitle in ticks.
  ///
  /// [format] - The format of the returned subtitle.
  ///
  /// [endPositionTicks] - Optional. The end position of the subtitle in ticks.
  ///
  /// [copyTimestamps] - Optional. Whether to copy the timestamps.
  ///
  /// [addVttTimeMap] - Optional. Whether to add a VTT time map.
  @GET('/Videos/{routeItemId}/{routeMediaSourceId}/Subtitles/{routeIndex}/{routeStartPositionTicks}/Stream.{routeFormat}')
  @DioResponseType(ResponseType.stream)
  Stream<String> getSubtitleWithTicks({
    @Path('routeItemId') required String routeItemId,
    @Path('routeMediaSourceId') required String routeMediaSourceId,
    @Path('routeIndex') required int routeIndex,
    @Path('routeStartPositionTicks') required int routeStartPositionTicks,
    @Path('routeFormat') required String routeFormat,
    @Query('copyTimestamps') bool? copyTimestamps = false,
    @Query('addVttTimeMap') bool? addVttTimeMap = false,
    @Deprecated('This is marked as deprecated')
    @Query('itemId') String? itemId,
    @Deprecated('This is marked as deprecated')
    @Query('mediaSourceId') String? mediaSourceId,
    @Deprecated('This is marked as deprecated')
    @Query('index') int? index,
    @Deprecated('This is marked as deprecated')
    @Query('startPositionTicks') int? startPositionTicks,
    @Deprecated('This is marked as deprecated')
    @Query('format') String? format,
    @Query('endPositionTicks') int? endPositionTicks,
  });

  /// Gets subtitles in a specified format.
  ///
  /// [routeItemId] - The (route) item id.
  ///
  /// [routeMediaSourceId] - The (route) media source id.
  ///
  /// [routeIndex] - The (route) subtitle stream index.
  ///
  /// [routeFormat] - The (route) format of the returned subtitle.
  ///
  /// [itemId] - The item id.
  ///
  /// [mediaSourceId] - The media source id.
  ///
  /// [index] - The subtitle stream index.
  ///
  /// [format] - The format of the returned subtitle.
  ///
  /// [endPositionTicks] - Optional. The end position of the subtitle in ticks.
  ///
  /// [copyTimestamps] - Optional. Whether to copy the timestamps.
  ///
  /// [addVttTimeMap] - Optional. Whether to add a VTT time map.
  ///
  /// [startPositionTicks] - The start position of the subtitle in ticks.
  @GET('/Videos/{routeItemId}/{routeMediaSourceId}/Subtitles/{routeIndex}/Stream.{routeFormat}')
  @DioResponseType(ResponseType.stream)
  Stream<String> getSubtitle({
    @Path('routeItemId') required String routeItemId,
    @Path('routeMediaSourceId') required String routeMediaSourceId,
    @Path('routeIndex') required int routeIndex,
    @Path('routeFormat') required String routeFormat,
    @Query('copyTimestamps') bool? copyTimestamps = false,
    @Query('addVttTimeMap') bool? addVttTimeMap = false,
    @Query('startPositionTicks') int? startPositionTicks = 0,
    @Deprecated('This is marked as deprecated')
    @Query('itemId') String? itemId,
    @Deprecated('This is marked as deprecated')
    @Query('mediaSourceId') String? mediaSourceId,
    @Deprecated('This is marked as deprecated')
    @Query('index') int? index,
    @Deprecated('This is marked as deprecated')
    @Query('format') String? format,
    @Query('endPositionTicks') int? endPositionTicks,
  });
}
