import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

import '../image_source.dart';
import '../tokens.dart';

/// Image réseau OptiFin, sans flash au chargement.
///
/// Le fond (BlurHash, ou couleur neutre) est peint **sous** l'image et y reste :
/// l'image arrive en fondu par-dessus, on ne voit donc jamais le noir entre
/// le placeholder et l'image (ce qui arrivait quand le placeholder disparaissait
/// instantanément pendant que l'image n'était encore qu'à moitié opaque).
///
/// `url` doit déjà être dimensionnée côté serveur (voir `JellyfinImageUrlBuilder`) ;
/// `decodeWidth` limite en plus la taille décodée en mémoire.
class OFImage extends StatelessWidget {
  const OFImage({
    super.key,
    required this.url,
    this.blurHash,
    this.fit = BoxFit.cover,
    this.decodeWidth,
    this.fallback,
    this.transparentPlaceholder = false,
  });

  final Uri? url;
  final String? blurHash;
  final BoxFit fit;

  /// Largeur physique à décoder (px). Si null, taille native de l'image.
  final int? decodeWidth;

  /// Widget affiché quand il n'y a pas d'image ou en cas d'erreur (jamais pendant le chargement).
  final Widget? fallback;

  /// Rien sous l'image pendant le chargement (logos posés sur un backdrop).
  final bool transparentPlaceholder;

  /// Provider exact utilisé par [OFImage] : à passer à `precacheImage` pour
  /// préparer une image avant son affichage (même clé de cache mémoire).
  static ImageProvider provider(Uri url, {int? decodeWidth}) => OFImageSource.isOverridden
      // Source locale (démo) : images déjà à la bonne taille, une seule clé de cache par image.
      ? OFImageSource.resolve(url.toString())
      : ResizeImage.resizeIfNeeded(decodeWidth, null, OFImageSource.resolve(url.toString()));

  Widget _base() {
    if (transparentPlaceholder) return const SizedBox.shrink();
    if (blurHash != null) {
      return BlurHash(hash: blurHash!, imageFit: fit, color: OFColors.surface, duration: Duration.zero);
    }
    return const ColoredBox(color: OFColors.surface);
  }

  @override
  Widget build(BuildContext context) {
    if (url == null) return fallback ?? _base();

    final fade = OFMotion.of(context).enabled ? const Duration(milliseconds: 200) : Duration.zero;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: _base()),
        if (OFImageSource.isOverridden)
          Image(
            image: provider(url!, decodeWidth: decodeWidth),
            fit: fit,
            gaplessPlayback: true,
          )
        else
          CachedNetworkImage(
            imageUrl: url.toString(),
            fit: fit,
            memCacheWidth: decodeWidth,
            fadeInDuration: fade,
            fadeOutDuration: Duration.zero,
            // Le placeholder est le fond peint dessous : rien à afficher ici.
            placeholder: (_, _) => const SizedBox.shrink(),
            errorWidget: (_, _, _) => fallback ?? const SizedBox.shrink(),
          ),
      ],
    );
  }
}
