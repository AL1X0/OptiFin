import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

import '../tokens.dart';

/// Image réseau OptiFin : placeholder BlurHash, fondu court, décodage à la taille affichée.
///
/// `url` doit déjà être dimensionnée côté serveur (voir `JellyfinImageUrlBuilder`).
/// `memCacheWidth` limite en plus la taille décodée en mémoire.
class OFImage extends StatelessWidget {
  const OFImage({
    super.key,
    required this.url,
    this.blurHash,
    this.fit = BoxFit.cover,
    this.decodeWidth,
    this.fallback,
  });

  final Uri? url;
  final String? blurHash;
  final BoxFit fit;

  /// Largeur physique à décoder (px). Si null, taille native de l'image.
  final int? decodeWidth;

  /// Widget affiché quand il n'y a pas d'image ou en cas d'erreur.
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final placeholder = blurHash != null
        ? BlurHash(hash: blurHash!, imageFit: fit, color: OFColors.surface)
        : const ColoredBox(color: OFColors.surface);

    if (url == null) return fallback ?? placeholder;

    final motion = OFMotion.of(context);
    return CachedNetworkImage(
      imageUrl: url.toString(),
      fit: fit,
      memCacheWidth: decodeWidth,
      fadeInDuration: motion.enabled ? const Duration(milliseconds: 150) : Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => fallback ?? placeholder,
    );
  }
}
