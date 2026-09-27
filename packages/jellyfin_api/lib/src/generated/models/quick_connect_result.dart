// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'quick_connect_result.g.dart';

/// Stores the state of an quick connect request.
@JsonSerializable()
class QuickConnectResult {
  const QuickConnectResult({
    this.authenticated,
    this.secret,
    this.code,
    this.deviceId,
    this.deviceName,
    this.appName,
    this.appVersion,
    this.dateAdded,
  });
  
  factory QuickConnectResult.fromJson(Map<String, Object?> json) => _$QuickConnectResultFromJson(json);
  
  /// Gets or sets a value indicating whether this request is authorized.
  @JsonKey(name: 'Authenticated')
  final bool? authenticated;

  /// Gets the secret value used to uniquely identify this request. Can be used to retrieve authentication information.
  @JsonKey(name: 'Secret')
  final String? secret;

  /// Gets the user facing code used so the user can quickly differentiate this request from others.
  @JsonKey(name: 'Code')
  final String? code;

  /// Gets the requesting device id.
  @JsonKey(name: 'DeviceId')
  final String? deviceId;

  /// Gets the requesting device name.
  @JsonKey(name: 'DeviceName')
  final String? deviceName;

  /// Gets the requesting app name.
  @JsonKey(name: 'AppName')
  final String? appName;

  /// Gets the requesting app version.
  @JsonKey(name: 'AppVersion')
  final String? appVersion;

  /// Gets or sets the DateTime that this request was created.
  @JsonKey(name: 'DateAdded')
  final DateTime? dateAdded;

  Map<String, Object?> toJson() => _$QuickConnectResultToJson(this);
}
