// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'queue_item.g.dart';

/// An item in a play queue.
@JsonSerializable()
class QueueItem {
  const QueueItem({
    this.id,
    this.playlistItemId,
  });
  
  factory QueueItem.fromJson(Map<String, Object?> json) => _$QueueItemFromJson(json);
  
  /// Gets or sets the item id.
  @JsonKey(name: 'Id')
  final String? id;

  /// Gets or sets the playlist item id.
  @JsonKey(name: 'PlaylistItemId')
  final String? playlistItemId;

  Map<String, Object?> toJson() => _$QueueItemToJson(this);
}
