// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'branding_options_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrandingOptionsDto _$BrandingOptionsDtoFromJson(Map<String, dynamic> json) =>
    BrandingOptionsDto(
      loginDisclaimer: json['LoginDisclaimer'] as String?,
      customCss: json['CustomCss'] as String?,
      splashscreenEnabled: json['SplashscreenEnabled'] as bool?,
    );

Map<String, dynamic> _$BrandingOptionsDtoToJson(BrandingOptionsDto instance) =>
    <String, dynamic>{
      'LoginDisclaimer': instance.loginDisclaimer,
      'CustomCss': instance.customCss,
      'SplashscreenEnabled': instance.splashscreenEnabled,
    };
