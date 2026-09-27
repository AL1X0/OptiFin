// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'branding_options_dto.g.dart';

/// The branding options DTO for API use.
/// This DTO excludes SplashscreenLocation to prevent it from being updated via API.
@JsonSerializable()
class BrandingOptionsDto {
  const BrandingOptionsDto({
    this.loginDisclaimer,
    this.customCss,
    this.splashscreenEnabled,
  });
  
  factory BrandingOptionsDto.fromJson(Map<String, Object?> json) => _$BrandingOptionsDtoFromJson(json);
  
  /// Gets or sets the login disclaimer.
  @JsonKey(name: 'LoginDisclaimer')
  final String? loginDisclaimer;

  /// Gets or sets the custom CSS.
  @JsonKey(name: 'CustomCss')
  final String? customCss;

  /// Gets or sets a value indicating whether to enable the splashscreen.
  @JsonKey(name: 'SplashscreenEnabled')
  final bool? splashscreenEnabled;

  Map<String, Object?> toJson() => _$BrandingOptionsDtoToJson(this);
}
