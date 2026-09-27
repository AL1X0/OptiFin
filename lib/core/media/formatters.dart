import 'media_item.dart';

/// Mise en forme des métadonnées (FR).
abstract final class MediaFormat {
  /// « 2 h 14 min », « 48 min ».
  static String? duration(Duration? d) {
    if (d == null || d.inMinutes <= 0) return null;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '$h h';
    return '$h h ${m.toString().padLeft(2, '0')} min';
  }

  /// « 1:02:03 » / « 12:34 » (positions de reprise).
  static String clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final mm = m.toString().padLeft(h > 0 ? 2 : 1, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  /// Années d'une série : « 2016 – 2022 », « 2019 – » (en cours).
  static String? years(MediaItem item) {
    final start = item.year ?? item.premiereDate?.year;
    if (start == null) return null;
    if (item.kind != MediaKind.series) return '$start';
    final end = item.endDate?.year;
    if (item.status == 'Continuing') return '$start –';
    if (end == null || end == start) return '$start';
    return '$start – $end';
  }

  static String? rating(double? r) => r == null || r <= 0 ? null : r.toStringAsFixed(1).replaceAll('.', ',');

  /// Ligne de métadonnées d'une fiche : « 2021 · 2 h 35 min · 12 · ★ 8,1 ».
  static List<String> metadataLine(MediaItem item) => [
        ?years(item),
        if (item.kind == MediaKind.series && item.childCount != null)
          '${item.childCount} saison${item.childCount! > 1 ? 's' : ''}'
        else
          ?duration(item.runtime),
        if (item.officialRating?.isNotEmpty ?? false) item.officialRating!,
        if (rating(item.communityRating) case final r?) '★ $r',
      ];

  /// Temps restant : « 1 h 12 min restantes ».
  static String? remaining(MediaItem item) {
    final total = item.runtime;
    if (total == null || item.user.positionTicks <= 0) return null;
    final left = total - item.resumePosition;
    final label = duration(left);
    return label == null ? null : '$label restantes';
  }
}
