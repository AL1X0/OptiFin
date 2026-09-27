// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'authentication_info.dart';

part 'authentication_info_query_result.g.dart';

/// Query result container.
@JsonSerializable()
class AuthenticationInfoQueryResult {
  const AuthenticationInfoQueryResult({
    this.items,
    this.totalRecordCount,
    this.startIndex,
  });
  
  factory AuthenticationInfoQueryResult.fromJson(Map<String, Object?> json) => _$AuthenticationInfoQueryResultFromJson(json);
  
  /// Gets or sets the items.
  @JsonKey(name: 'Items')
  final List<AuthenticationInfo>? items;

  /// Gets or sets the total number of records available.
  @JsonKey(name: 'TotalRecordCount')
  final int? totalRecordCount;

  /// Gets or sets the index of the first record in Items.
  @JsonKey(name: 'StartIndex')
  final int? startIndex;

  Map<String, Object?> toJson() => _$AuthenticationInfoQueryResultToJson(this);
}
