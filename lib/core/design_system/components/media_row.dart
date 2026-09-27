import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

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
    final gutter = OFSpacing.screenGutter(MediaQuery.sizeOf(context).width);
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
            itemCount: itemCount,
            itemBuilder: (context, i) => Align(
              alignment: Alignment.topLeft,
              child: itemBuilder(context, i),
            ),
          ),
        ),
      ],
    );
  }
}
