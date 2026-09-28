import '../media/media_item.dart';

/// Construit les URL d'images redimensionnées côté serveur.
///
/// Règle perf : on demande toujours `maxWidth` = largeur affichée × devicePixelRatio,
/// arrondie au palier supérieur pour maximiser les hits de cache.
class JellyfinImageUrlBuilder {
  const JellyfinImageUrlBuilder(this.baseUrl);

  final Uri baseUrl;

  /// Paliers de largeur : évite de fragmenter le cache pour 1 px d'écart.
  static const widthBuckets = [120, 180, 240, 320, 480, 640, 800, 1080, 1280, 1920, 2560, 3840];

  static int bucketFor(double logicalWidth, double devicePixelRatio) {
    final physical = (logicalWidth * devicePixelRatio).ceil();
    for (final b in widthBuckets) {
      if (b >= physical) return b;
    }
    return widthBuckets.last;
  }

  static String _apiName(ImageKind kind) => switch (kind) {
    ImageKind.primary => 'Primary',
    ImageKind.backdrop => 'Backdrop',
    ImageKind.logo => 'Logo',
    ImageKind.thumb => 'Thumb',
    ImageKind.banner => 'Banner',
    ImageKind.art => 'Art',
  };

  /// URL d'une image référencée, à la largeur d'affichage.
  Uri image(ImageRef ref, {required double logicalWidth, required double devicePixelRatio, int quality = 90}) {
    final type = _apiName(ref.type);
    final path = ref.type == ImageKind.backdrop
        ? 'Items/${ref.itemId}/Images/$type/${ref.index}'
        : 'Items/${ref.itemId}/Images/$type';
    return _build(path, {
      'maxWidth': '${bucketFor(logicalWidth, devicePixelRatio)}',
      'quality': '$quality',
      'format': 'Webp',
      'tag': ref.tag,
    });
  }

  /// Nullable-friendly : null si pas d'image.
  Uri? maybe(ImageRef? ref, {required double logicalWidth, required double devicePixelRatio, int quality = 90}) =>
      ref == null ? null : image(ref, logicalWidth: logicalWidth, devicePixelRatio: devicePixelRatio, quality: quality);

  Uri userAvatar({
    required String userId,
    required double logicalWidth,
    required double devicePixelRatio,
    String? tag,
  }) {
    return _build('Users/$userId/Images/Primary', {
      'maxWidth': '${bucketFor(logicalWidth, devicePixelRatio)}',
      'quality': '90',
      'format': 'Webp',
      'tag': ?tag,
    });
  }

  /// Vignette d'un chapitre (générée par le serveur).
  Uri chapterImage(
    String itemId,
    int index, {
    String? tag,
    required double logicalWidth,
    required double devicePixelRatio,
  }) => _build('Items/$itemId/Images/Chapter/$index', {
    'maxWidth': '${bucketFor(logicalWidth, devicePixelRatio)}',
    'quality': '85',
    'format': 'Webp',
    'tag': ?tag,
  });

  /// Planche de vignettes trickplay (JPEG). Nécessite l'en-tête d'authentification.
  Uri trickplaySheet(String itemId, {required int width, required int sheet, String? mediaSourceId}) =>
      _build('Videos/$itemId/Trickplay/$width/$sheet.jpg', {'mediaSourceId': ?mediaSourceId});

  Uri _build(String relativePath, Map<String, String> query) {
    final basePath = baseUrl.path.endsWith('/') ? baseUrl.path : '${baseUrl.path}/';
    return baseUrl.replace(path: '$basePath$relativePath', queryParameters: query.isEmpty ? null : query);
  }
}
