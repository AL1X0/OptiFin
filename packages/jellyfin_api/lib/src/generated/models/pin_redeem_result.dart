// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'pin_redeem_result.g.dart';

@JsonSerializable()
class PinRedeemResult {
  const PinRedeemResult({
    this.success,
    this.usersReset,
  });
  
  factory PinRedeemResult.fromJson(Map<String, Object?> json) => _$PinRedeemResultFromJson(json);
  
  /// Gets or sets a value indicating whether this MediaBrowser.Model.Users.PinRedeemResult is success.
  @JsonKey(name: 'Success')
  final bool? success;

  /// Gets or sets the users reset.
  @JsonKey(name: 'UsersReset')
  final List<String>? usersReset;

  Map<String, Object?> toJson() => _$PinRedeemResultToJson(this);
}
