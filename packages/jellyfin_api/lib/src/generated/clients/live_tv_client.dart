// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/base_item_dto.dart';
import '../models/base_item_dto_query_result.dart';
import '../models/channel_mapping_options_dto.dart';
import '../models/get_programs_dto.dart';
import '../models/guide_info.dart';
import '../models/image_type.dart';
import '../models/item_fields.dart';
import '../models/item_sort_by.dart';
import '../models/listings_provider_info.dart';
import '../models/live_tv_info.dart';
import '../models/name_id_pair.dart';
import '../models/series_timer_info_dto.dart';
import '../models/series_timer_info_dto_query_result.dart';
import '../models/set_channel_mapping_dto.dart';
import '../models/sort_order.dart';
import '../models/status.dart';
import '../models/timer_info_dto.dart';
import '../models/timer_info_dto_query_result.dart';
import '../models/tuner_channel_mapping.dart';
import '../models/tuner_host_info.dart';
import '../models/type.dart';

part 'live_tv_client.g.dart';

@RestApi()
abstract class LiveTvClient {
  factory LiveTvClient(Dio dio, {String? baseUrl}) = _LiveTvClient;

  /// Get channel mapping options.
  ///
  /// [providerId] - Provider id.
  @GET('/LiveTv/ChannelMappingOptions')
  Future<ChannelMappingOptionsDto> getChannelMappingOptions({
    @Query('providerId') String? providerId,
  });

  /// Set channel mappings.
  ///
  /// [body] - Set channel mapping dto.
  @POST('/LiveTv/ChannelMappings')
  Future<TunerChannelMapping> setChannelMapping({
    @Body() required SetChannelMappingDto body,
  });

  /// Gets available live tv channels.
  ///
  /// [type] - Optional. Filter by channel type.
  ///
  /// [userId] - Optional. Filter by user and attach user data.
  ///
  /// [startIndex] - Optional. The record index to start at. All items with a lower index will be dropped from the results.
  ///
  /// [isMovie] - Optional. Filter for movies.
  ///
  /// [isSeries] - Optional. Filter for series.
  ///
  /// [isNews] - Optional. Filter for news.
  ///
  /// [isKids] - Optional. Filter for kids.
  ///
  /// [isSports] - Optional. Filter for sports.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [isFavorite] - Optional. Filter by channels that are favorites, or not.
  ///
  /// [isLiked] - Optional. Filter by channels that are liked, or not.
  ///
  /// [isDisliked] - Optional. Filter by channels that are disliked, or not.
  ///
  /// [enableImages] - Optional. Include image information in output.
  ///
  /// [imageTypeLimit] - Optional. The max number of images to return, per image type.
  ///
  /// [enableImageTypes] - "Optional. The image types to include in the output.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output.
  ///
  /// [enableUserData] - Optional. Include user data.
  ///
  /// [sortBy] - Optional. Key to sort by.
  ///
  /// [sortOrder] - Optional. Sort order.
  ///
  /// [enableFavoriteSorting] - Optional. Incorporate favorite and like status into channel sorting.
  ///
  /// [addCurrentProgram] - Optional. Adds current program info to each channel.
  @GET('/LiveTv/Channels')
  Future<BaseItemDtoQueryResult> getLiveTvChannels({
    @Query('enableFavoriteSorting') bool? enableFavoriteSorting = false,
    @Query('addCurrentProgram') bool? addCurrentProgram = true,
    @Query('type') Type? type,
    @Query('userId') String? userId,
    @Query('startIndex') int? startIndex,
    @Query('isMovie') bool? isMovie,
    @Query('isSeries') bool? isSeries,
    @Query('isNews') bool? isNews,
    @Query('isKids') bool? isKids,
    @Query('isSports') bool? isSports,
    @Query('limit') int? limit,
    @Query('isFavorite') bool? isFavorite,
    @Query('isLiked') bool? isLiked,
    @Query('isDisliked') bool? isDisliked,
    @Query('enableImages') bool? enableImages,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
    @Query('fields') List<ItemFields>? fields,
    @Query('enableUserData') bool? enableUserData,
    @Query('sortBy') List<ItemSortBy>? sortBy,
    @Query('sortOrder') SortOrder? sortOrder,
  });

  /// Gets a live tv channel.
  ///
  /// [channelId] - Channel id.
  ///
  /// [userId] - Optional. Attach user data.
  @GET('/LiveTv/Channels/{channelId}')
  Future<BaseItemDto> getChannel({
    @Path('channelId') required String channelId,
    @Query('userId') String? userId,
  });

  /// Get guide info.
  @GET('/LiveTv/GuideInfo')
  Future<GuideInfo> getGuideInfo();

  /// Gets available live tv services.
  @GET('/LiveTv/Info')
  Future<LiveTvInfo> getLiveTvInfo();

  /// Adds a listings provider.
  ///
  /// [pw] - Password.
  ///
  /// [validateListings] - Validate listings.
  ///
  /// [validateLogin] - Validate login.
  @POST('/LiveTv/ListingProviders')
  Future<ListingsProviderInfo> addListingProvider({
    @Query('validateListings') bool? validateListings = false,
    @Query('validateLogin') bool? validateLogin = false,
    @Query('pw') String? pw,
    @Body() ListingsProviderInfo? body,
  });

  /// Delete listing provider.
  ///
  /// [id] - Listing provider id.
  @DELETE('/LiveTv/ListingProviders')
  Future<void> deleteListingProvider({
    @Query('id') String? id,
  });

  /// Gets default listings provider info.
  @GET('/LiveTv/ListingProviders/Default')
  Future<ListingsProviderInfo> getDefaultListingProvider();

  /// Gets available lineups.
  ///
  /// [id] - Provider id.
  ///
  /// [type] - Provider type.
  ///
  /// [location] - Location.
  ///
  /// [country] - Country.
  @GET('/LiveTv/ListingProviders/Lineups')
  Future<List<NameIdPair>> getLineups({
    @Query('id') String? id,
    @Query('type') String? type,
    @Query('location') String? location,
    @Query('country') String? country,
  });

  /// Gets available countries.
  @GET('/LiveTv/ListingProviders/SchedulesDirect/Countries')
  @DioResponseType(ResponseType.stream)
  Stream<String> getSchedulesDirectCountries();

  /// Gets a live tv recording stream.
  ///
  /// [recordingId] - Recording id.
  @GET('/LiveTv/LiveRecordings/{recordingId}/stream')
  @DioResponseType(ResponseType.stream)
  Stream<String> getLiveRecordingFile({
    @Path('recordingId') required String recordingId,
  });

  /// Gets a live tv channel stream.
  ///
  /// [streamId] - Stream id.
  ///
  /// [container] - Container type.
  @GET('/LiveTv/LiveStreamFiles/{streamId}/stream.{container}')
  @DioResponseType(ResponseType.stream)
  Stream<String> getLiveStreamFile({
    @Path('streamId') required String streamId,
    @Path('container') required String container,
  });

  /// Gets available live tv epgs.
  ///
  /// [channelIds] - The channels to return guide information for.
  ///
  /// [userId] - Optional. Filter by user id.
  ///
  /// [minStartDate] - Optional. The minimum premiere start date.
  ///
  /// [hasAired] - Optional. Filter by programs that have completed airing, or not.
  ///
  /// [isAiring] - Optional. Filter by programs that are currently airing, or not.
  ///
  /// [maxStartDate] - Optional. The maximum premiere start date.
  ///
  /// [minEndDate] - Optional. The minimum premiere end date.
  ///
  /// [maxEndDate] - Optional. The maximum premiere end date.
  ///
  /// [isMovie] - Optional. Filter for movies.
  ///
  /// [isSeries] - Optional. Filter for series.
  ///
  /// [isNews] - Optional. Filter for news.
  ///
  /// [isKids] - Optional. Filter for kids.
  ///
  /// [isSports] - Optional. Filter for sports.
  ///
  /// [startIndex] - Optional. The record index to start at. All items with a lower index will be dropped from the results.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [sortBy] - Optional. Specify one or more sort orders, comma delimited. Options: Name, StartDate.
  ///
  /// [sortOrder] - Sort Order - Ascending,Descending.
  ///
  /// [genres] - The genres to return guide information for.
  ///
  /// [genreIds] - The genre ids to return guide information for.
  ///
  /// [enableImages] - Optional. Include image information in output.
  ///
  /// [imageTypeLimit] - Optional. The max number of images to return, per image type.
  ///
  /// [enableImageTypes] - Optional. The image types to include in the output.
  ///
  /// [enableUserData] - Optional. Include user data.
  ///
  /// [seriesTimerId] - Optional. Filter by series timer id.
  ///
  /// [librarySeriesId] - Optional. Filter by library series id.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output.
  ///
  /// [enableTotalRecordCount] - Retrieve total record count.
  @GET('/LiveTv/Programs')
  Future<BaseItemDtoQueryResult> getLiveTvPrograms({
    @Query('enableTotalRecordCount') bool? enableTotalRecordCount = true,
    @Query('channelIds') List<String>? channelIds,
    @Query('userId') String? userId,
    @Query('minStartDate') DateTime? minStartDate,
    @Query('hasAired') bool? hasAired,
    @Query('isAiring') bool? isAiring,
    @Query('maxStartDate') DateTime? maxStartDate,
    @Query('minEndDate') DateTime? minEndDate,
    @Query('maxEndDate') DateTime? maxEndDate,
    @Query('isMovie') bool? isMovie,
    @Query('isSeries') bool? isSeries,
    @Query('isNews') bool? isNews,
    @Query('isKids') bool? isKids,
    @Query('isSports') bool? isSports,
    @Query('startIndex') int? startIndex,
    @Query('limit') int? limit,
    @Query('sortBy') List<ItemSortBy>? sortBy,
    @Query('sortOrder') List<SortOrder>? sortOrder,
    @Query('genres') List<String>? genres,
    @Query('genreIds') List<String>? genreIds,
    @Query('enableImages') bool? enableImages,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
    @Query('enableUserData') bool? enableUserData,
    @Query('seriesTimerId') String? seriesTimerId,
    @Query('librarySeriesId') String? librarySeriesId,
    @Query('fields') List<ItemFields>? fields,
  });

  /// Gets available live tv epgs.
  ///
  /// [body] - Get programs dto.
  @POST('/LiveTv/Programs')
  Future<BaseItemDtoQueryResult> getPrograms({
    @Body() GetProgramsDto? body,
  });

  /// Gets a live tv program.
  ///
  /// [programId] - Program id.
  ///
  /// [userId] - Optional. Attach user data.
  @GET('/LiveTv/Programs/{programId}')
  Future<BaseItemDto> getProgram({
    @Path('programId') required String programId,
    @Query('userId') String? userId,
  });

  /// Gets recommended live tv epgs.
  ///
  /// [userId] - Optional. filter by user id.
  ///
  /// [startIndex] - Optional. The record index to start at. All items with a lower index will be dropped from the results.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [isAiring] - Optional. Filter by programs that are currently airing, or not.
  ///
  /// [hasAired] - Optional. Filter by programs that have completed airing, or not.
  ///
  /// [isSeries] - Optional. Filter for series.
  ///
  /// [isMovie] - Optional. Filter for movies.
  ///
  /// [isNews] - Optional. Filter for news.
  ///
  /// [isKids] - Optional. Filter for kids.
  ///
  /// [isSports] - Optional. Filter for sports.
  ///
  /// [enableImages] - Optional. Include image information in output.
  ///
  /// [imageTypeLimit] - Optional. The max number of images to return, per image type.
  ///
  /// [enableImageTypes] - Optional. The image types to include in the output.
  ///
  /// [genreIds] - The genres to return guide information for.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output.
  ///
  /// [enableUserData] - Optional. include user data.
  ///
  /// [enableTotalRecordCount] - Retrieve total record count.
  @GET('/LiveTv/Programs/Recommended')
  Future<BaseItemDtoQueryResult> getRecommendedPrograms({
    @Query('enableTotalRecordCount') bool? enableTotalRecordCount = true,
    @Query('userId') String? userId,
    @Query('startIndex') int? startIndex,
    @Query('limit') int? limit,
    @Query('isAiring') bool? isAiring,
    @Query('hasAired') bool? hasAired,
    @Query('isSeries') bool? isSeries,
    @Query('isMovie') bool? isMovie,
    @Query('isNews') bool? isNews,
    @Query('isKids') bool? isKids,
    @Query('isSports') bool? isSports,
    @Query('enableImages') bool? enableImages,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
    @Query('genreIds') List<String>? genreIds,
    @Query('fields') List<ItemFields>? fields,
    @Query('enableUserData') bool? enableUserData,
  });

  /// Gets live tv recordings.
  ///
  /// [channelId] - Optional. Filter by channel id.
  ///
  /// [userId] - Optional. Filter by user and attach user data.
  ///
  /// [startIndex] - Optional. The record index to start at. All items with a lower index will be dropped from the results.
  ///
  /// [limit] - Optional. The maximum number of records to return.
  ///
  /// [status] - Optional. Filter by recording status.
  ///
  /// [isInProgress] - Optional. Filter by recordings that are in progress, or not.
  ///
  /// [seriesTimerId] - Optional. Filter by recordings belonging to a series timer.
  ///
  /// [enableImages] - Optional. Include image information in output.
  ///
  /// [imageTypeLimit] - Optional. The max number of images to return, per image type.
  ///
  /// [enableImageTypes] - Optional. The image types to include in the output.
  ///
  /// [fields] - Optional. Specify additional fields of information to return in the output.
  ///
  /// [enableUserData] - Optional. Include user data.
  ///
  /// [isMovie] - Optional. Filter for movies.
  ///
  /// [isSeries] - Optional. Filter for series.
  ///
  /// [isKids] - Optional. Filter for kids.
  ///
  /// [isSports] - Optional. Filter for sports.
  ///
  /// [isNews] - Optional. Filter for news.
  ///
  /// [isLibraryItem] - Optional. Filter for is library item.
  ///
  /// [enableTotalRecordCount] - Optional. Return total record count.
  @GET('/LiveTv/Recordings')
  Future<BaseItemDtoQueryResult> getRecordings({
    @Query('enableTotalRecordCount') bool? enableTotalRecordCount = true,
    @Query('channelId') String? channelId,
    @Query('userId') String? userId,
    @Query('startIndex') int? startIndex,
    @Query('limit') int? limit,
    @Query('status') Status? status,
    @Query('isInProgress') bool? isInProgress,
    @Query('seriesTimerId') String? seriesTimerId,
    @Query('enableImages') bool? enableImages,
    @Query('imageTypeLimit') int? imageTypeLimit,
    @Query('enableImageTypes') List<ImageType>? enableImageTypes,
    @Query('fields') List<ItemFields>? fields,
    @Query('enableUserData') bool? enableUserData,
    @Query('isMovie') bool? isMovie,
    @Query('isSeries') bool? isSeries,
    @Query('isKids') bool? isKids,
    @Query('isSports') bool? isSports,
    @Query('isNews') bool? isNews,
    @Query('isLibraryItem') bool? isLibraryItem,
  });

  /// Gets a live tv recording.
  ///
  /// [recordingId] - Recording id.
  ///
  /// [userId] - Optional. Attach user data.
  @GET('/LiveTv/Recordings/{recordingId}')
  Future<BaseItemDto> getRecording({
    @Path('recordingId') required String recordingId,
    @Query('userId') String? userId,
  });

  /// Deletes a live tv recording.
  ///
  /// [recordingId] - Recording id.
  @DELETE('/LiveTv/Recordings/{recordingId}')
  Future<void> deleteRecording({
    @Path('recordingId') required String recordingId,
  });

  /// Gets recording folders.
  ///
  /// [userId] - Optional. Filter by user and attach user data.
  @GET('/LiveTv/Recordings/Folders')
  Future<BaseItemDtoQueryResult> getRecordingFolders({
    @Query('userId') String? userId,
  });

  /// Gets live tv series timers.
  ///
  /// [sortBy] - Optional. Sort by SortName or Priority.
  ///
  /// [sortOrder] - Optional. Sort in Ascending or Descending order.
  @GET('/LiveTv/SeriesTimers')
  Future<SeriesTimerInfoDtoQueryResult> getSeriesTimers({
    @Query('sortBy') String? sortBy,
    @Query('sortOrder') SortOrder? sortOrder,
  });

  /// Creates a live tv series timer.
  ///
  /// [body] - Class SeriesTimerInfoDto.
  @POST('/LiveTv/SeriesTimers')
  Future<void> createSeriesTimer({
    @Body() SeriesTimerInfoDto? body,
  });

  /// Gets a live tv series timer.
  ///
  /// [timerId] - Timer id.
  @GET('/LiveTv/SeriesTimers/{timerId}')
  Future<SeriesTimerInfoDto> getSeriesTimer({
    @Path('timerId') required String timerId,
  });

  /// Cancels a live tv series timer.
  ///
  /// [timerId] - Timer id.
  @DELETE('/LiveTv/SeriesTimers/{timerId}')
  Future<void> cancelSeriesTimer({
    @Path('timerId') required String timerId,
  });

  /// Updates a live tv series timer.
  ///
  /// [timerId] - Timer id.
  ///
  /// [body] - Class SeriesTimerInfoDto.
  @POST('/LiveTv/SeriesTimers/{timerId}')
  Future<void> updateSeriesTimer({
    @Path('timerId') required String timerId,
    @Body() SeriesTimerInfoDto? body,
  });

  /// Gets the live tv timers.
  ///
  /// [channelId] - Optional. Filter by channel id.
  ///
  /// [seriesTimerId] - Optional. Filter by timers belonging to a series timer.
  ///
  /// [isActive] - Optional. Filter by timers that are active.
  ///
  /// [isScheduled] - Optional. Filter by timers that are scheduled.
  @GET('/LiveTv/Timers')
  Future<TimerInfoDtoQueryResult> getTimers({
    @Query('channelId') String? channelId,
    @Query('seriesTimerId') String? seriesTimerId,
    @Query('isActive') bool? isActive,
    @Query('isScheduled') bool? isScheduled,
  });

  /// Creates a live tv timer.
  @POST('/LiveTv/Timers')
  Future<void> createTimer({
    @Body() TimerInfoDto? body,
  });

  /// Gets a timer.
  ///
  /// [timerId] - Timer id.
  @GET('/LiveTv/Timers/{timerId}')
  Future<TimerInfoDto> getTimer({
    @Path('timerId') required String timerId,
  });

  /// Cancels a live tv timer.
  ///
  /// [timerId] - Timer id.
  @DELETE('/LiveTv/Timers/{timerId}')
  Future<void> cancelTimer({
    @Path('timerId') required String timerId,
  });

  /// Updates a live tv timer.
  ///
  /// [timerId] - Timer id.
  @POST('/LiveTv/Timers/{timerId}')
  Future<void> updateTimer({
    @Path('timerId') required String timerId,
    @Body() TimerInfoDto? body,
  });

  /// Gets the default values for a new timer.
  ///
  /// [programId] - Optional. To attach default values based on a program.
  @GET('/LiveTv/Timers/Defaults')
  Future<SeriesTimerInfoDto> getDefaultTimer({
    @Query('programId') String? programId,
  });

  /// Adds a tuner host.
  @POST('/LiveTv/TunerHosts')
  Future<TunerHostInfo> addTunerHost({
    @Body() TunerHostInfo? body,
  });

  /// Deletes a tuner host.
  ///
  /// [id] - Tuner host id.
  @DELETE('/LiveTv/TunerHosts')
  Future<void> deleteTunerHost({
    @Query('id') String? id,
  });

  /// Get tuner host types.
  @GET('/LiveTv/TunerHosts/Types')
  Future<List<NameIdPair>> getTunerHostTypes();

  /// Resets a tv tuner.
  ///
  /// [tunerId] - Tuner id.
  @POST('/LiveTv/Tuners/{tunerId}/Reset')
  Future<void> resetTuner({
    @Path('tunerId') required String tunerId,
  });

  /// Discover tuners.
  ///
  /// [newDevicesOnly] - Only discover new tuners.
  @GET('/LiveTv/Tuners/Discover')
  Future<List<TunerHostInfo>> discoverTuners({
    @Query('newDevicesOnly') bool? newDevicesOnly = false,
  });

  /// Discover tuners.
  ///
  /// [newDevicesOnly] - Only discover new tuners.
  @GET('/LiveTv/Tuners/Discvover')
  Future<List<TunerHostInfo>> discvoverTuners({
    @Query('newDevicesOnly') bool? newDevicesOnly = false,
  });
}
