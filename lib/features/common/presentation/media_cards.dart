import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/media/media_item.dart';
import '../../../core/providers.dart';
import '../../home/domain/home_data.dart';

/// Largeur de carte selon le style et la largeur d'écran.
double cardWidthFor(CardStyle style, double screenWidth) {
  final poster = OFBreakpoint.of(screenWidth).posterWidth;
  return switch (style) {
    CardStyle.poster => poster,
    CardStyle.square => poster * 1.15,
    // Plafonnée : sur tablette, 4 à 5 cartes visibles plutôt que 3 énormes.
    CardStyle.landscape => poster * 1.9 > 264 ? 264.0 : poster * 1.9,
  };
}

/// Hauteur totale d'une carte (image + 2 lignes de texte).
double cardHeightFor(CardStyle style, double width, {bool showTitle = true}) {
  final image = switch (style) {
    CardStyle.poster => width * 3 / 2,
    CardStyle.square => width,
    CardStyle.landscape => width * 9 / 16,
  };
  return image + (showTitle ? 48 : 0);
}

/// Carte média branchée sur les données Jellyfin et la navigation.
class MediaCard extends ConsumerWidget {
  const MediaCard({
    super.key,
    required this.item,
    required this.style,
    required this.width,
    this.onTap,
    this.heroScope,
  });

  final MediaItem item;
  final CardStyle style;
  final double width;
  final VoidCallback? onTap;

  /// Identifie la rangée/grille : le même élément peut apparaître dans plusieurs
  /// rangées d'une page, or un tag Hero doit y être unique.
  final String? heroScope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroTag = heroScope == null ? null : '$heroScope:${item.id}';
    final images = ref.watch(imageUrlBuilderProvider);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final ref0 = switch (style) {
      CardStyle.landscape => item.landscape,
      _ => item.poster ?? item.primary,
    };
    final data = MediaCardData(
      id: item.id,
      title: _title(item, style),
      subtitle: _subtitle(item, style),
      imageUrl: images.maybe(ref0, logicalWidth: width, devicePixelRatio: dpr),
      blurHash: ref0?.blurHash,
      progress: item.user.progress,
      played: item.user.played && item.kind != MediaKind.series && item.kind != MediaKind.season,
    );
    final tap = onTap ?? () => context.openItem(item, heroTag: heroTag);
    return switch (style) {
      CardStyle.poster => PosterCard(data: data, width: width, onTap: tap, heroTag: heroTag),
      CardStyle.square => SquareCard(data: data, width: width, onTap: tap, heroTag: heroTag),
      CardStyle.landscape => LandscapeCard(data: data, width: width, onTap: tap, heroTag: heroTag),
    };
  }

  static String _title(MediaItem i, CardStyle style) =>
      i.kind == MediaKind.episode && style == CardStyle.landscape && i.seriesName != null ? i.seriesName! : i.name;

  static String? _subtitle(MediaItem i, CardStyle style) {
    if (i.kind == MediaKind.episode) {
      final label = i.episodeLabel;
      if (style == CardStyle.landscape) return [?label, i.name].join(' · ');
      return label;
    }
    if (i.kind == MediaKind.series && (i.user.unplayedCount ?? 0) > 0) {
      final n = i.user.unplayedCount!;
      return '$n épisode${n > 1 ? 's' : ''} non vu${n > 1 ? 's' : ''}';
    }
    return i.year?.toString();
  }
}

/// Rangée horizontale de cartes média.
class MediaItemsRow extends StatelessWidget {
  const MediaItemsRow({
    super.key,
    required this.title,
    required this.items,
    required this.style,
    this.onSeeAll,
    this.heroScope,
  });

  final String title;
  final List<MediaItem> items;
  final CardStyle style;
  final VoidCallback? onSeeAll;
  final String? heroScope;

  @override
  Widget build(BuildContext context) {
    final width = cardWidthFor(style, MediaQuery.sizeOf(context).width);
    return MediaRow(
      title: title,
      itemCount: items.length,
      itemExtent: width + OFSpacing.md,
      height: cardHeightFor(style, width),
      onSeeAll: onSeeAll,
      itemBuilder: (context, i) => MediaCard(item: items[i], style: style, width: width, heroScope: heroScope),
    );
  }
}

/// Rangée squelette pendant le premier chargement.
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key, required this.style});

  final CardStyle style;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context).width;
    final width = cardWidthFor(style, screen);
    final gutter = OFSpacing.screenGutter(screen);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 160, height: 20, radius: OFRadius.smAll),
          const SizedBox(height: OFSpacing.md),
          SizedBox(
            height: cardHeightFor(style, width, showTitle: false),
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                maxWidth: double.infinity,
                child: Row(
                  children: [
                    for (var i = 0; i < 6; i++) ...[
                      SkeletonBox(
                        width: width,
                        aspectRatio: switch (style) {
                          CardStyle.poster => 2 / 3,
                          CardStyle.square => 1,
                          CardStyle.landscape => 16 / 9,
                        },
                      ),
                      const SizedBox(width: OFSpacing.md),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Message d'erreur / vide centré avec action optionnelle.
class StatusMessage extends StatelessWidget {
  const StatusMessage({super.key, required this.text, this.icon, this.onRetry});

  final String text;
  final IconData? icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(OFSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 40, color: OFColors.textTertiary),
              const SizedBox(height: OFSpacing.lg),
            ],
            Text(
              text,
              textAlign: TextAlign.center,
              style: OFTypography.body.copyWith(color: OFColors.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: OFSpacing.lg),
              OFButton.secondary(label: 'Réessayer', onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}
