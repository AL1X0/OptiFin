/// Compléments d'une lecture : chapitres, vignettes de trickplay, segments
/// (intro, récap, générique…) et épisode suivant. Pur, testé.
library;

import '../../../core/media/media_item.dart';

class Chapter {
  const Chapter({required this.index, required this.start, required this.name, this.imageTag});

  final int index;
  final Duration start;
  final String name;

  /// Vignette du chapitre (`/Items/{id}/Images/Chapter/{index}`), si le serveur l'a générée.
  final String? imageTag;
}

/// Vignettes de prévisualisation générées par Jellyfin (10.9+) : planches de
/// `tileWidth × tileHeight` images de `width × height`, une toutes les `interval`.
class TrickplayManifest {
  const TrickplayManifest({
    required this.width,
    required this.height,
    required this.tileWidth,
    required this.tileHeight,
    required this.thumbnailCount,
    required this.interval,
  });

  final int width;
  final int height;
  final int tileWidth;
  final int tileHeight;
  final int thumbnailCount;
  final Duration interval;

  int get perSheet => tileWidth * tileHeight;

  /// Planche et position dans la planche de la vignette à afficher pour [position].
  TrickplayTile tileAt(Duration position) {
    final ms = interval.inMilliseconds <= 0 ? 1 : interval.inMilliseconds;
    final index = (position.inMilliseconds ~/ ms).clamp(0, thumbnailCount <= 0 ? 0 : thumbnailCount - 1);
    final inSheet = index % perSheet;
    return TrickplayTile(sheet: index ~/ perSheet, column: inSheet % tileWidth, row: inSheet ~/ tileWidth);
  }
}

class TrickplayTile {
  const TrickplayTile({required this.sheet, required this.column, required this.row});

  final int sheet;
  final int column;
  final int row;

  @override
  bool operator ==(Object other) =>
      other is TrickplayTile && other.sheet == sheet && other.column == column && other.row == row;

  @override
  int get hashCode => Object.hash(sheet, column, row);

  @override
  String toString() => 'planche $sheet ($column, $row)';
}

enum SegmentType {
  intro('Passer l’intro'),
  recap('Passer le récapitulatif'),
  preview('Passer l’aperçu'),
  commercial('Passer la publicité'),
  outro('Passer le générique');

  const SegmentType(this.skipLabel);
  final String skipLabel;
}

class MediaSegment {
  const MediaSegment({required this.type, required this.start, required this.end});

  final SegmentType type;
  final Duration start;
  final Duration end;

  /// Le bouton « Passer » n'a de sens que si le segment dure un peu.
  bool get isSkippable => end - start >= const Duration(seconds: 3);

  bool contains(Duration position) => position >= start && position < end;
}

/// Sous-titre trouvé par un fournisseur du serveur (plugin OpenSubtitles…).
class RemoteSubtitle {
  const RemoteSubtitle({
    required this.id,
    required this.name,
    this.provider,
    this.format,
    this.language,
    this.downloads,
    this.rating,
    this.hashMatch = false,
    this.hearingImpaired = false,
    this.forced = false,
  });

  final String id;
  final String name;
  final String? provider;
  final String? format;
  final String? language;
  final int? downloads;
  final double? rating;

  /// Correspond exactement au fichier (même empreinte) : synchro garantie.
  final bool hashMatch;
  final bool hearingImpaired;
  final bool forced;

  String get detail => [
    ?provider,
    if (format != null) format!.toUpperCase(),
    if (hashMatch) 'Synchro exacte',
    if (hearingImpaired) 'Malentendants',
    if (forced) 'Forcés',
    if (downloads != null) '$downloads téléchargements',
  ].join(' · ');
}

class PlaybackExtras {
  const PlaybackExtras({this.chapters = const [], this.trickplay, this.segments = const [], this.nextEpisode});

  static const empty = PlaybackExtras();

  final List<Chapter> chapters;
  final TrickplayManifest? trickplay;
  final List<MediaSegment> segments;

  /// Épisode suivant de la série (null pour un film ou le dernier épisode).
  final MediaItem? nextEpisode;

  /// Segment à proposer de passer à [position] (hors générique : géré par « épisode suivant »
  /// quand il y en a un).
  MediaSegment? skippableAt(Duration position) {
    for (final s in segments) {
      if (!s.isSkippable || !s.contains(position)) continue;
      // Dernière seconde du segment : trop tard pour proposer de le passer.
      if (s.end - position < const Duration(seconds: 1)) continue;
      if (s.type == SegmentType.outro && nextEpisode != null) continue;
      return s;
    }
    return null;
  }

  Chapter? chapterAt(Duration position) {
    Chapter? current;
    for (final c in chapters) {
      if (c.start <= position) current = c;
    }
    return current;
  }

  /// Moment où proposer l'épisode suivant : début du générique s'il est connu,
  /// sinon 30 s avant la fin (jamais avant la moitié de l'épisode).
  Duration? upNextAt(Duration duration) {
    if (nextEpisode == null || duration <= Duration.zero) return null;
    final outro = segments.where((s) => s.type == SegmentType.outro && s.end >= duration * 0.8).firstOrNull;
    final at = outro?.start ?? duration - const Duration(seconds: 30);
    return at < duration ~/ 2 ? duration ~/ 2 : at;
  }
}
