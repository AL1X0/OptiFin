// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/branding_options_dto.dart';

part 'branding_client.g.dart';

@RestApi()
abstract class BrandingClient {
  factory BrandingClient(Dio dio, {String? baseUrl}) = _BrandingClient;

  /// Gets branding configuration.
  @GET('/Branding/Configuration')
  Future<BrandingOptionsDto> getBrandingOptions();

  /// Gets branding css.
  @GET('/Branding/Css')
  Future<String> getBrandingCss();

  /// Gets branding css.
  @GET('/Branding/Css.css')
  Future<String> getBrandingCss2();
}
