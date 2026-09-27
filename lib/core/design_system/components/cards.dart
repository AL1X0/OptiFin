import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../tokens.dart';
import 'of_image.dart';

/// Données minimales d'une carte média, indépendantes du DTO Jellyfin.
class MediaCardData {
  const MediaCardData({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.blurHash,
    this.progress,
    this.played = false,
  });

  final String id;
  final String title;
  final String? subtitle;
  final Uri? imageUrl;
  final String? blurHash;

  /// Progression 0..1 ; null = pas de barre.
  final double? progress;
  final bool played;
}

/// Carte affiche 2:3.
class PosterCard extends StatelessWidget {
  const PosterCard({super.key, required this.data, required this.width, this.onTap, this.showTitle = true});

  final MediaCardData data;
  final double width;
  final VoidCallback? onTap;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return _CardFrame(
      data: data,
      width: width,
      aspectRatio: 2 / 3,
      heroTag: 'poster-${data.id}',
      decodeWidth: (width * dpr).ceil(),
      showTitle: showTitle,
      onTap: onTap,
    );
  }
}

/// Carte paysage 16:9 (Reprendre, épisodes).
class LandscapeCard extends StatelessWidget {
  const LandscapeCard({super.key, required this.data, required this.width, this.onTap, this.showTitle = true});

  final MediaCardData data;
  final double width;
  final VoidCallback? onTap;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return _CardFrame(
      data: data,
      width: width,
      aspectRatio: 16 / 9,
      heroTag: 'thumb-${data.id}',
      decodeWidth: (width * dpr).ceil(),
      showTitle: showTitle,
      onTap: onTap,
    );
  }
}

class _CardFrame extends StatefulWidget {
  const _CardFrame({
    required this.data,
    required this.width,
    required this.aspectRatio,
    required this.heroTag,
    required this.decodeWidth,
    required this.showTitle,
    required this.onTap,
  });

  final MediaCardData data;
  final double width;
  final double aspectRatio;
  final String heroTag;
  final int decodeWidth;
  final bool showTitle;
  final VoidCallback? onTap;

  @override
  State<_CardFrame> createState() => _CardFrameState();
}

class _CardFrameState extends State<_CardFrame> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final motion = OFMotion.of(context);
    final progress = data.progress;

    final artwork = ClipRRect(
      borderRadius: OFRadius.mdAll,
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: widget.heroTag,
              child: OFImage(
                url: data.imageUrl,
                blurHash: data.blurHash,
                decodeWidth: widget.decodeWidth,
                fallback: _TitleFallback(title: data.title),
              ),
            ),
            if (data.played)
              const Positioned(top: OFSpacing.sm, right: OFSpacing.sm, child: _PlayedDot()),
            if (progress != null && progress > 0 && progress < 1)
              Positioned(
                left: OFSpacing.sm,
                right: OFSpacing.sm,
                bottom: OFSpacing.sm,
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                  child: LinearProgressIndicator(value: progress, minHeight: 3),
                ),
              ),
          ],
        ),
      ),
    );

    final semanticsLabel = [
      data.title,
      if (data.subtitle != null) data.subtitle!,
      if (progress != null && progress > 0 && progress < 1) '${(progress * 100).round()} % regardé',
      if (data.played) 'Vu',
    ].join(', ');

    final onTap = widget.onTap == null
        ? null
        : () {
            HapticFeedback.selectionClick();
            widget.onTap!();
          };

    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: motion.fast,
          curve: OFMotion.fastCurve,
          child: SizedBox(
            width: widget.width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                artwork,
                if (widget.showTitle) ...[
                  const SizedBox(height: OFSpacing.sm),
                  Text(data.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: OFTypography.callout),
                  if (data.subtitle != null)
                    Text(
                      data.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OFTypography.caption.copyWith(color: OFColors.textSecondary),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayedDot extends StatelessWidget {
  const _PlayedDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(color: Color(0xCC000000), shape: BoxShape.circle),
      child: const Icon(Icons.check_rounded, size: 14, color: OFColors.textPrimary),
    );
  }
}

/// Affiché pour les contenus sans image : le titre sur fond neutre.
class _TitleFallback extends StatelessWidget {
  const _TitleFallback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: OFColors.surfaceRaised,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(OFSpacing.md),
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: OFTypography.callout.copyWith(color: OFColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
