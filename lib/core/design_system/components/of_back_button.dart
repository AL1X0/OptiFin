import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../tokens.dart';
import 'focusable.dart';
import 'glass_surface.dart';
import 'of_button.dart';

/// Bouton retour OptiFin façon iOS : icône chevron seule ou pilule de verre
/// affichant le titre de l'écran précédent.
class OFBackButton extends StatelessWidget {
  const OFBackButton({super.key, this.previousTitle, required this.onPressed});

  /// Titre de l'écran précédent. Si nul ou vide, seule l'icône est affichée.
  final String? previousTitle;

  /// Action déclenchée lors du tap ou de la sélection au clavier.
  final VoidCallback onPressed;

  void _handleTap() {
    HapticFeedback.selectionClick();
    onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final title = previousTitle;
    if (title == null || title.isEmpty) {
      return OFIconButton(icon: Icons.arrow_back_ios_new_rounded, tooltip: 'Retour', onPressed: onPressed);
    }

    const radius = BorderRadius.all(Radius.circular(22));

    return Tooltip(
      message: 'Retour',
      child: Semantics(
        button: true,
        label: 'Retour à $title',
        excludeSemantics: true,
        child: OFFocusable(
          onSelect: _handleTap,
          borderRadius: radius,
          child: GestureDetector(
            onTap: _handleTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160, minHeight: 44, maxHeight: 44),
              child: GlassSurface(
                borderRadius: radius,
                padding: const EdgeInsets.only(left: 10, right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: OFColors.textPrimary),
                    const SizedBox(width: OFSpacing.xs),
                    Flexible(
                      child: Text(
                        title,
                        style: OFTypography.callout.copyWith(fontWeight: FontWeight.w600, color: OFColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
