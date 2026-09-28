import '../../../core/media/media_item.dart';

/// État d'un téléchargement.
enum DownloadStatus {
  queued('En attente'),
  running('Téléchargement'),
  paused('En pause'),
  complete('Téléchargé'),
  failed('Échec');

  const DownloadStatus(this.label);
  final String label;

  bool get active => this == queued || this == running;

  static DownloadStatus parse(String? name) =>
      DownloadStatus.values.where((s) => s.name == name).firstOrNull ?? DownloadStatus.failed;
}

/// Film ou épisode téléchargé (ou en cours) pour la lecture hors connexion.
class DownloadEntry {
  const DownloadEntry({
    required this.item,
    required this.status,
    required this.progress,
    required this.sizeBytes,
    required this.filePath,
    required this.createdAt,
    this.posterPath,
    this.backdropPath,
  });

  /// Fiche conservée localement (affichable sans réseau).
  final MediaItem item;
  final DownloadStatus status;

  /// 0..1.
  final double progress;

  /// Taille totale attendue (octets) ; 0 si encore inconnue.
  final int sizeBytes;

  /// Chemins absolus (vidéo, affiche, fond).
  final String filePath;
  final String? posterPath;
  final String? backdropPath;
  final DateTime createdAt;

  String get itemId => item.id;
  bool get isComplete => status == DownloadStatus.complete;

  /// Octets présents sur l'appareil (estimation pendant le téléchargement).
  int get bytesOnDisk => isComplete ? sizeBytes : (sizeBytes * progress).round();
}

/// Groupe affiché dans « Téléchargements » : un film seul, ou une série et ses épisodes.
class DownloadGroup {
  const DownloadGroup({required this.id, required this.title, required this.entries, this.seriesId});

  /// Identifiant stable : id du film ou de la série.
  final String id;
  final String title;

  /// Série : épisodes triés par saison puis numéro.
  final List<DownloadEntry> entries;
  final String? seriesId;

  bool get isSeries => seriesId != null;
  DownloadEntry get first => entries.first;
  int get totalBytes => entries.fold(0, (sum, e) => sum + e.bytesOnDisk);
  int get completeCount => entries.where((e) => e.isComplete).length;
}

/// Regroupe les téléchargements : films (du plus récent au plus ancien), séries (épisodes
/// ordonnés), dans l'ordre du dernier ajout. Pur, testé.
List<DownloadGroup> groupDownloads(List<DownloadEntry> entries) {
  final sorted = [...entries]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final groups = <String, DownloadGroup>{};
  for (final e in sorted) {
    final seriesId = e.item.kind == MediaKind.episode ? e.item.seriesId : null;
    final key = seriesId ?? e.itemId;
    final existing = groups[key];
    groups[key] = DownloadGroup(
      id: key,
      title: seriesId != null ? (e.item.seriesName ?? e.item.name) : e.item.name,
      seriesId: seriesId,
      entries: [...?existing?.entries, e],
    );
  }
  return [
    for (final g in groups.values)
      if (g.isSeries)
        DownloadGroup(
          id: g.id,
          title: g.title,
          seriesId: g.seriesId,
          entries: [...g.entries]
            ..sort(
              (a, b) => ((a.item.parentIndexNumber ?? 0) * 10000 + (a.item.indexNumber ?? 0)).compareTo(
                (b.item.parentIndexNumber ?? 0) * 10000 + (b.item.indexNumber ?? 0),
              ),
            ),
        )
      else
        g,
  ];
}

/// « 1,4 Go », « 820 Mo ».
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 Mo';
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1).replaceAll('.', ',')} Go';
  return '${(bytes / mb).round()} Mo';
}
