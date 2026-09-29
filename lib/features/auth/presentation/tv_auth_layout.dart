import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';

/// Mise en page des écrans de connexion sur téléviseur : présentation à gauche, choix à
/// droite (liste pilotée à la télécommande), comme les écrans d'accueil des applis TV.
class TvAuthLayout extends StatelessWidget {
  const TvAuthLayout({super.key, required this.title, required this.subtitle, required this.children, this.footer});

  final String title;
  final String subtitle;

  /// Ligne discrète sous le sous-titre (adresse du serveur…).
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.9, -0.8),
            radius: 1.4,
            colors: [accent.withValues(alpha: 0.22), OFColors.background],
          ),
        ),
        child: FadeSlideIn(
          offset: 24,
          child: Padding(
            // Marges de sécurité des téléviseurs.
            padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 40),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(header: true, child: Text(title, style: OFTypography.display.copyWith(fontSize: 44))),
                      const SizedBox(height: OFSpacing.md),
                      Text(
                        subtitle,
                        style: OFTypography.title2.copyWith(color: OFColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                      if (footer != null) ...[
                        const SizedBox(height: OFSpacing.sm),
                        Text(footer!, style: OFTypography.callout.copyWith(color: OFColors.textTertiary)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 48),
                Expanded(
                  flex: 6,
                  child: FocusTraversalGroup(
                    child: Center(
                      child: ListView(
                        shrinkWrap: true,
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.symmetric(vertical: OFSpacing.lg),
                        children: children,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne sélectionnable des écrans de connexion TV (compte, serveur) : grossit et s'entoure
/// d'un liseré blanc au focus.
class TvChoiceTile extends StatelessWidget {
  const TvChoiceTile({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onSelect,
    this.autofocus = false,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback? onSelect;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: OFSpacing.sm),
      child: TvFocusable(
        autofocus: autofocus,
        onSelect: onSelect,
        scale: 1.03,
        borderRadius: OFRadius.mdAll,
        child: GestureDetector(
          onTap: onSelect,
          child: Container(
            padding: const EdgeInsets.all(OFSpacing.md),
            decoration: const BoxDecoration(color: OFColors.surface, borderRadius: OFRadius.mdAll),
            child: Row(
              children: [
                leading,
                const SizedBox(width: OFSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: OFTypography.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        subtitle,
                        style: OFTypography.caption.copyWith(color: OFColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: OFColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Intertitre discret des écrans de connexion TV.
class TvSectionLabel extends StatelessWidget {
  const TvSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: OFSpacing.lg, bottom: OFSpacing.sm),
    child: Text(
      text.toUpperCase(),
      style: OFTypography.caption.copyWith(color: OFColors.textTertiary, letterSpacing: 1.2),
    ),
  );
}
