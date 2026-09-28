import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../core/media/media_item.dart';
import 'router.dart';

/// Navigation vers les contenus, en restant dans l'onglet courant
/// (la barre d'onglets reste visible et les transitions Hero restent possibles).
extension OFNavigation on BuildContext {
  String get _branch {
    final segments = GoRouterState.of(this).uri.pathSegments;
    return segments.isEmpty ? 'home' : segments.first;
  }

  /// [heroTag] : tag Hero de la carte source, repris par la fiche pour la transition.
  void openItem(MediaItem item, {String? heroTag}) {
    switch (item.kind) {
      case MediaKind.person:
        openPerson(item.id);
      case MediaKind.collectionFolder || MediaKind.folder || MediaKind.photoAlbum:
        openLibrary(item.id);
      case MediaKind.season when item.seriesId != null:
        push('/$_branch/item/${item.seriesId}?season=${item.id}');
      default:
        push('/$_branch/item/${item.id}', extra: heroTag);
    }
  }

  void openItemId(String id) => push('/$_branch/item/$id');

  /// Lance la lecture. [start] null = reprendre où le serveur l'a enregistré.
  void play(String itemId, {Duration? start}) => push(Routes.play(itemId, start: start));
  void openPerson(String id) => push('/$_branch/person/$id');
  void openLibrary(String id) => push('/$_branch/library/$id');
  void openGenre(NamedRef genre) =>
      push(Uri(path: '/$_branch/genre/${genre.id}', queryParameters: {'name': genre.name}).toString());
  void openStudio(NamedRef studio) =>
      push(Uri(path: '/$_branch/studio/${studio.id}', queryParameters: {'name': studio.name}).toString());
}
