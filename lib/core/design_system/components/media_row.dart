import 'package:flutter/material.dart';

import '../theme.dart';
import '../device.dart';
import '../tokens.dart';
import 'motion.dart';

/// Rangée horizontale virtualisée (titre + « Tout voir »).
class MediaRow extends StatelessWidget {
  const MediaRow({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemExtent,
    required this.height,
    this.onSeeAll,
  });

  final String title;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Largeur d'un élément + espacement : permet à la liste de sauter le layout.
  final double itemExtent;
  final double height;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final row = _build(context);
    if (!OFDevice.tv) return row;
    // TV : la rangée qui reçoit le focus se place en haut de l'écran, titre compris (sinon
    // seule la carte est ramenée à l'écran, titre coupé), comme sur l'Apple TV.
    return Builder(
      builder: (context) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) {
          if (!focused) return;
          Scrollable.ensureVisible(
            context,
            alignment: 0.12,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        },
        child: row,
      ),
    );
  }

  Widget _build(BuildContext context) {
    final gutter = OFSpacing.gutterOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 0, gutter - OFSpacing.sm, OFSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: OFTypography.title2, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: Text('Tout voir', style: OFTypography.callout.copyWith(color: OFColors.textSecondary)),
                ),
            ],
          ),
        ),
        SizedBox(
          height: height,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: gutter),
            itemExtent: itemExtent,
            // TV : la carte focalisée grossit et déborde sans être rognée.
            clipBehavior: OFDevice.tv ? Clip.none : Clip.hardEdge,
            itemCount: itemCount,
            // Arrivée des cartes de gauche à droite (dans la fenêtre d'entrée de l'écran).
            itemBuilder: (context, i) => Align(
              alignment: Alignment.topLeft,
              child: FadeSlideIn(
                delay: staggerDelay(i, max: 6),
                axis: Axis.horizontal,
                offset: 24,
                child: itemBuilder(context, i),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
