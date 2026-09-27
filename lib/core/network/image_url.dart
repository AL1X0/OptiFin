/// Types d'images Jellyfin utilisés par l'app.
enum JellyfinImageType { primary, backdrop, logo, thumb, banner, art }

extension on JellyfinImageType {
  String get apiName => switch (this) {
        JellyfinImageType.primary => 'Primary',
        JellyfinImageType.backdrop => 'Backdrop',
        JellyfinImageType.logo => 'Logo',
        JellyfinImageType.thumb => 'Thumb',
        JellyfinImageType.banner => 'Banner',
        JellyfinImageType.art => 'Art',
      };
}

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

  Uri item({
    required String itemId,
    required JellyfinImageType type,
    required double logicalWidth,
    required double devicePixelRatio,
    String? tag,
    int index = 0,
    int quality = 90,
  }) {
    final path = type == JellyfinImageType.backdrop
        ? 'Items/$itemId/Images/${type.apiName}/$index'
        : 'Items/$itemId/Images/${type.apiName}';
    return _build(path, {
      'maxWidth': '${bucketFor(logicalWidth, devicePixelRatio)}',
      'quality': '$quality',
      'format': 'Webp',
      'tag': ?tag,
    });
  }

  Uri userAvatar({required String userId, required double logicalWidth, required double devicePixelRatio, String? tag}) {
    return _build('Users/$userId/Images/Primary', {
      'maxWidth': '${bucketFor(logicalWidth, devicePixelRatio)}',
      'quality': '90',
      'format': 'Webp',
      'tag': ?tag,
    });
  }

  Uri _build(String relativePath, Map<String, String> query) {
    final basePath = baseUrl.path.endsWith('/') ? baseUrl.path : '${baseUrl.path}/';
    return baseUrl.replace(path: '$basePath$relativePath', queryParameters: query);
  }
}
