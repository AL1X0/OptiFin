// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/collection_creation_result.dart';

part 'collection_client.g.dart';

@RestApi()
abstract class CollectionClient {
  factory CollectionClient(Dio dio, {String? baseUrl}) = _CollectionClient;

  /// Creates a new collection.
  ///
  /// [name] - The name of the collection.
  ///
  /// [ids] - Item Ids to add to the collection.
  ///
  /// [parentId] - Optional. Create the collection within a specific folder.
  ///
  /// [isLocked] - Whether or not to lock the new collection.
  @POST('/Collections')
  Future<CollectionCreationResult> createCollection({
    @Query('isLocked') bool? isLocked = false,
    @Query('name') String? name,
    @Query('ids') List<String>? ids,
    @Query('parentId') String? parentId,
  });

  /// Adds items to a collection.
  ///
  /// [collectionId] - The collection id.
  ///
  /// [ids] - Item ids, comma delimited.
  @POST('/Collections/{collectionId}/Items')
  Future<void> addToCollection({
    @Path('collectionId') required String collectionId,
    @Query('ids') required List<String> ids,
  });

  /// Removes items from a collection.
  ///
  /// [collectionId] - The collection id.
  ///
  /// [ids] - Item ids, comma delimited.
  @DELETE('/Collections/{collectionId}/Items')
  Future<void> removeFromCollection({
    @Path('collectionId') required String collectionId,
    @Query('ids') required List<String> ids,
  });
}
