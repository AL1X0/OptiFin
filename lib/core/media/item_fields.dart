import 'package:jellyfin_api/jellyfin_api.dart';

/// Jeux de `Fields` demandés au serveur : on ne demande que ce qui est affiché.
abstract final class ItemFieldSets {
  /// Cartes (rangées, grilles) : de quoi afficher image + titre + progression.
  static const card = [ItemFields.primaryImageAspectRatio, ItemFields.childCount];

  /// Carrousel « à la une » : synopsis + genres en plus.
  static const featured = [ItemFields.overview, ItemFields.genres, ItemFields.primaryImageAspectRatio];

  /// Épisodes dans une fiche série : synopsis court + durée.
  static const episode = [ItemFields.overview, ItemFields.primaryImageAspectRatio];

  /// Fiche complète.
  static const detail = [
    ItemFields.overview,
    ItemFields.genres,
    ItemFields.studios,
    ItemFields.people,
    ItemFields.taglines,
    ItemFields.remoteTrailers,
    ItemFields.mediaSources,
    ItemFields.mediaStreams,
    ItemFields.childCount,
    ItemFields.originalTitle,
    ItemFields.primaryImageAspectRatio,
    ItemFields.externalUrls,
  ];

  /// Types d'images utiles aux cartes (évite les tags inutiles dans les réponses).
  static const cardImages = [ImageType.primary, ImageType.backdrop, ImageType.thumb, ImageType.logo];
}
