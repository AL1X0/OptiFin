// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'dart:convert';
import 'dart:io';

import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/activity_log_entry_query_result.dart';
import '../models/activity_log_sort_by.dart';
import '../models/branding_options_dto.dart';
import '../models/client_log_document_response_dto.dart';
import '../models/end_point_info.dart';
import '../models/log_file.dart';
import '../models/metadata_options.dart';
import '../models/public_system_info.dart';
import '../models/server_configuration.dart';
import '../models/severity.dart';
import '../models/sort_order.dart';
import '../models/system_info.dart';
import '../models/system_storage_dto.dart';
import '../models/utc_time_response.dart';

part 'system_client.g.dart';

@RestApi()
abstract class SystemClient {
  factory SystemClient(Dio dio, {String? baseUrl}) = _SystemClient;

  /// Gets activity log entries.
  ///
  /// [startIndex] - The record index to start at. All items with a lower index will be dropped from the results.
  ///
  /// [limit] - The maximum number of records to return.
  ///
  /// [minDate] - The minimum date.
  ///
  /// [maxDate] - The maximum date.
  ///
  /// [hasUserId] - Filter log entries if it has user id, or not.
  ///
  /// [name] - Filter by name.
  ///
  /// [overview] - Filter by overview.
  ///
  /// [shortOverview] - Filter by short overview.
  ///
  /// [type] - Filter by type.
  ///
  /// [itemId] - Filter by item id.
  ///
  /// [username] - Filter by username.
  ///
  /// [severity] - Filter by log severity.
  ///
  /// [sortBy] - Specify one or more sort orders. Format: SortBy=Name,Type.
  ///
  /// [sortOrder] - Sort Order..
  @GET('/System/ActivityLog/Entries')
  Future<ActivityLogEntryQueryResult> getLogEntries({
    @Query('startIndex') int? startIndex,
    @Query('limit') int? limit,
    @Query('minDate') DateTime? minDate,
    @Query('maxDate') DateTime? maxDate,
    @Query('hasUserId') bool? hasUserId,
    @Query('name') String? name,
    @Query('overview') String? overview,
    @Query('shortOverview') String? shortOverview,
    @Query('type') String? type,
    @Query('itemId') String? itemId,
    @Query('username') String? username,
    @Query('severity') Severity? severity,
    @Query('sortBy') List<ActivityLogSortBy>? sortBy,
    @Query('sortOrder') List<SortOrder>? sortOrder,
  });

  /// Upload a document.
  @POST('/ClientLog/Document')
  Future<ClientLogDocumentResponseDto> logFile({
    @Body() required File body,
  });

  /// Gets application configuration.
  @GET('/System/Configuration')
  Future<ServerConfiguration> getConfiguration();

  /// Updates application configuration.
  ///
  /// [body] - Represents the server configuration.
  @POST('/System/Configuration')
  Future<void> updateConfiguration({
    @Body() required ServerConfiguration body,
  });

  /// Gets a named configuration.
  ///
  /// [key] - Configuration key.
  @GET('/System/Configuration/{key}')
  @DioResponseType(ResponseType.stream)
  Stream<String> getNamedConfiguration({
    @Path('key') required String key,
  });

  /// Updates named configuration.
  ///
  /// [key] - Configuration key.
  @POST('/System/Configuration/{key}')
  Future<void> updateNamedConfiguration({
    @Path('key') required String key,
    @Body() required dynamic body,
  });

  /// Updates branding configuration.
  ///
  /// [body] - The branding options DTO for API use.
  /// This DTO excludes SplashscreenLocation to prevent it from being updated via API.
  @POST('/System/Configuration/Branding')
  Future<void> updateBrandingConfiguration({
    @Body() required BrandingOptionsDto body,
  });

  /// Gets a default MetadataOptions object.
  @GET('/System/Configuration/MetadataOptions/Default')
  Future<MetadataOptions> getDefaultMetadataOptions();

  /// Gets information about the request endpoint.
  @GET('/System/Endpoint')
  Future<EndPointInfo> getEndpointInfo();

  /// Gets information about the server.
  @GET('/System/Info')
  Future<SystemInfo> getSystemInfo();

  /// Gets public information about the server.
  @GET('/System/Info/Public')
  Future<PublicSystemInfo> getPublicSystemInfo();

  /// Gets information about the server.
  @GET('/System/Info/Storage')
  Future<SystemStorageDto> getSystemStorage();

  /// Gets a list of available server log files.
  @GET('/System/Logs')
  Future<List<LogFile>> getServerLogs();

  /// Gets a log file.
  ///
  /// [name] - The name of the log file to get.
  @GET('/System/Logs/Log')
  @DioResponseType(ResponseType.stream)
  Stream<String> getLogFile({
    @Query('name') required String name,
  });

  /// Pings the system.
  @GET('/System/Ping')
  Future<String> getPingSystem();

  /// Pings the system.
  @POST('/System/Ping')
  Future<String> postPingSystem();

  /// Restarts the application.
  @POST('/System/Restart')
  Future<void> restartApplication();

  /// Shuts down the application.
  @POST('/System/Shutdown')
  Future<void> shutdownApplication();

  /// Gets the current UTC time.
  @GET('/GetUtcTime')
  Future<UtcTimeResponse> getUtcTime();
}
