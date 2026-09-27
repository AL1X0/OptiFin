// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'display_preferences_dto_scroll_direction.dart';
import 'display_preferences_dto_sort_order.dart';

part 'display_preferences_dto.g.dart';

/// Defines the display preferences for any item that supports them (usually Folders).
@JsonSerializable()
class DisplayPreferencesDto {
  const DisplayPreferencesDto({
    required this.id,
    required this.viewType,
    required this.sortBy,
    required this.indexBy,
    required this.rememberIndexing,
    required this.primaryImageHeight,
    required this.primaryImageWidth,
    required this.customPrefs,
    required this.scrollDirection,
    required this.showBackdrop,
    required this.rememberSorting,
    required this.sortOrder,
    required this.showSidebar,
    required this.client,
  });
  
  factory DisplayPreferencesDto.fromJson(Map<String, Object?> json) => _$DisplayPreferencesDtoFromJson(json);
  
  /// Gets or sets the user id.
  @JsonKey(name: 'Id')
  final String? id;

  /// Gets or sets the type of the view.
  @JsonKey(name: 'ViewType')
  final String? viewType;

  /// Gets or sets the sort by.
  @JsonKey(name: 'SortBy')
  final String? sortBy;

  /// Gets or sets the index by.
  @JsonKey(name: 'IndexBy')
  final String? indexBy;

  /// Gets or sets a value indicating whether [remember indexing].
  @JsonKey(name: 'RememberIndexing')
  final bool? rememberIndexing;

  /// Gets or sets the height of the primary image.
  @JsonKey(name: 'PrimaryImageHeight')
  final int? primaryImageHeight;

  /// Gets or sets the width of the primary image.
  @JsonKey(name: 'PrimaryImageWidth')
  final int? primaryImageWidth;

  /// Gets or sets the custom prefs.
  @JsonKey(name: 'CustomPrefs')
  final Map<String, String?>? customPrefs;

  /// An enum representing the axis that should be scrolled.
  @JsonKey(name: 'ScrollDirection')
  final DisplayPreferencesDtoScrollDirection? scrollDirection;

  /// Gets or sets a value indicating whether to show backdrops on this item.
  @JsonKey(name: 'ShowBackdrop')
  final bool? showBackdrop;

  /// Gets or sets a value indicating whether [remember sorting].
  @JsonKey(name: 'RememberSorting')
  final bool? rememberSorting;

  /// An enum representing the sorting order.
  @JsonKey(name: 'SortOrder')
  final DisplayPreferencesDtoSortOrder? sortOrder;

  /// Gets or sets a value indicating whether [show sidebar].
  @JsonKey(name: 'ShowSidebar')
  final bool? showSidebar;

  /// Gets or sets the client.
  @JsonKey(name: 'Client')
  final String? client;

  Map<String, Object?> toJson() => _$DisplayPreferencesDtoToJson(this);
}
