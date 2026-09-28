import 'package:flutter/material.dart';

/// Ligne de métadonnées (« 2021 · 2 h 35 min · 12 · ★ 8,1 ») : la note s'affiche
/// avec une vraie icône d'étoile, nette et identique sur toutes les plateformes
/// (le caractère « ★ » dépend des polices disponibles).
class MetadataLine extends StatelessWidget {
  const MetadataLine(
    this.parts, {
    super.key,
    required this.style,
    this.separator = '  ·  ',
    this.textAlign,
    this.maxLines,
  });

  final List<String> parts;
  final TextStyle style;
  final String separator;
  final TextAlign? textAlign;
  final int? maxLines;

  static const _star = '★ ';

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? 14;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final (i, part) in parts.indexed) ...[
            if (i > 0) TextSpan(text: separator),
            if (part.startsWith(_star)) ...[
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Icon(Icons.star_rounded, size: size * 1.05, color: const Color(0xFFF5C451)),
                ),
              ),
              TextSpan(text: part.substring(_star.length)),
            ] else
              TextSpan(text: part),
          ],
        ],
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}
