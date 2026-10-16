import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import 'glass_surface.dart';

/// En-tête sliver persistant avec grand titre pliable façon iOS.
///
/// Déplié : affiche un grand titre [OFTypography.title1] et les actions à droite.
/// Replié : bascule vers un titre centré [OFTypography.headline] dans une barre
/// compacte avec fond en verre [GlassSurface].
class OFLargeTitleSliver extends StatelessWidget {
  const OFLargeTitleSliver({super.key, required this.title, this.actions = const <Widget>[]});

  /// Titre de l'écran affiché dans l'en-tête.
  final String title;

  /// Actions interactives alignées sur la droite (boutons, avatar, etc.).
  final List<Widget> actions;

  static const double _barHeight = 52.0;
  static const double _expansionHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final gutter = OFSpacing.gutterOf(context);

    return SliverPersistentHeader(
      pinned: true,
      delegate: _OFLargeTitleSliverDelegate(title: title, actions: actions, topPadding: topPadding, gutter: gutter),
    );
  }
}

class _OFLargeTitleSliverDelegate extends SliverPersistentHeaderDelegate {
  _OFLargeTitleSliverDelegate({
    required this.title,
    required this.actions,
    required this.topPadding,
    required this.gutter,
  });

  final String title;
  final List<Widget> actions;
  final double topPadding;
  final double gutter;

  @override
  double get minExtent => topPadding + OFLargeTitleSliver._barHeight;

  @override
  double get maxExtent => minExtent + OFLargeTitleSliver._expansionHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final delta = maxExtent - minExtent;
    final t = delta <= 0 ? 0.0 : (shrinkOffset / delta).clamp(0.0, 1.0);

    final largeOpacity = (1.0 - t).clamp(0.0, 1.0);
    final smallOpacity = t.clamp(0.0, 1.0);

    // Marge réservée pour centrer le petit titre sans empiéter sur les actions.
    final actionsReserve = actions.isEmpty ? 0.0 : (actions.length * 44.0 + OFSpacing.md);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Fond verre opaque progressif lors du repli sous la barre d'état.
        if (t > 0)
          Positioned.fill(
            child: Opacity(
              opacity: t,
              child: const GlassSurface(
                borderRadius: BorderRadius.zero,
                child: ColoredBox(color: Color(0xB3000000)),
              ),
            ),
          ),

        // Titre compact centré dans la barre de 52 px sous la zone d'état.
        Positioned(
          top: topPadding,
          left: gutter,
          right: gutter,
          height: OFLargeTitleSliver._barHeight,
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: actionsReserve),
              child: Opacity(
                opacity: smallOpacity,
                child: Transform.translate(
                  offset: Offset(0, (1.0 - t) * 6.0),
                  child: IgnorePointer(
                    ignoring: t < 0.5,
                    child: ExcludeSemantics(
                      excluding: t < 0.5,
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: OFTypography.headline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Ligne basse glissant vers la barre compacte : grand titre et actions.
        Positioned(
          left: gutter,
          right: gutter,
          bottom: 0,
          height: OFLargeTitleSliver._barHeight,
          child: Row(
            children: [
              Expanded(
                child: Opacity(
                  opacity: largeOpacity,
                  child: Transform.translate(
                    offset: Offset(0, -t * 4.0),
                    child: IgnorePointer(
                      ignoring: t >= 0.5,
                      child: ExcludeSemantics(
                        excluding: t >= 0.5,
                        child: Semantics(
                          header: true,
                          child: Text(title, style: OFTypography.title1, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: OFSpacing.md),
                Row(mainAxisSize: MainAxisSize.min, children: actions),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_OFLargeTitleSliverDelegate oldDelegate) {
    return oldDelegate.title != title ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.gutter != gutter ||
        !listEquals(oldDelegate.actions, actions);
  }
}
