import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:optifin_native_player/optifin_native_player.dart' show NativeGlassView;

import '../core/design_system/design_system.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _tabs = [
  _Tab('Accueil', Icons.home_outlined, Icons.home_rounded),
  _Tab('Bibliothèques', Icons.video_library_outlined, Icons.video_library_rounded),
  _Tab('Recherche', Icons.search_rounded, Icons.search_rounded),
  _Tab('Téléchargements', Icons.download_for_offline_outlined, Icons.download_for_offline_rounded),
];

/// Coquille de navigation : barre d'onglets flottante en pilule de verre, centrée en bas,
/// sur tous les appareils (sur iOS, vrai verre natif). Le contenu défile dessous (extendBody).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _select(int index) {
    HapticFeedback.selectionClick();
    // Re-taper l'onglet courant revient à sa racine.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: _FloatingTabBar(current: shell.currentIndex, onSelect: _select),
    );
  }
}

/// Pilule flottante : icône au-dessus du libellé sur téléphone (portrait comme paysage),
/// côte à côte sur tablette. L'onglet actif est posé sur une pastille claire.
class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final accent = Theme.of(context).colorScheme.primary;
    final motion = OFMotion.of(context);
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final nativeGlass = NativeGlassView.supported;

    // Rétrécit plutôt que de déborder (petits écrans, grandes polices).
    final row = FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, tab) in _tabs.indexed)
              Semantics(
                selected: i == current,
                button: true,
                label: tab.label,
                excludeSemantics: true,
                onTap: () => onSelect(i),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: motion.standard,
                    curve: OFMotion.standardCurve,
                    height: tablet ? 46 : 54,
                    constraints: BoxConstraints(minWidth: tablet ? 0 : 88),
                    padding: EdgeInsets.symmetric(horizontal: tablet ? OFSpacing.lg + 2 : OFSpacing.md),
                    decoration: BoxDecoration(
                      color: i == current ? const Color(0x24FFFFFF) : const Color(0x00FFFFFF),
                      borderRadius: const BorderRadius.all(Radius.circular(OFRadius.pill)),
                    ),
                    child: _TabContent(tab: tab, selected: i == current, accent: accent, stacked: !tablet),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: bottom > 0 ? bottom - OFSpacing.xs : OFSpacing.md, top: OFSpacing.sm),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - OFSpacing.lg * 2),
          child: nativeGlass
              // iOS : vrai Liquid Glass natif sous les icônes (vue UIKit), liseré compris.
              ? Stack(
                  children: [
                    const Positioned.fill(child: NativeGlassView()),
                    row,
                  ],
                )
              : LiquidGlass(shade: 0.45, child: row),
        ),
      ),
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({required this.tab, required this.selected, required this.accent, required this.stacked});

  final _Tab tab;
  final bool selected;
  final Color accent;

  /// Icône au-dessus du libellé (téléphone) plutôt qu'à côté (tablette).
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final motion = OFMotion.of(context);
    final icon = AnimatedStateIcon(
      icon: selected ? tab.selectedIcon : tab.icon,
      color: selected ? accent : OFColors.textSecondary,
      size: stacked ? 23 : 24,
    );
    final label = AnimatedDefaultTextStyle(
      duration: motion.standard,
      style: DefaultTextStyle.of(context).style.merge(
        (stacked ? OFTypography.caption.copyWith(fontSize: 10.5) : OFTypography.callout).copyWith(
          color: selected ? OFColors.textPrimary : OFColors.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      child: Text(tab.label, maxLines: 1),
    );
    return stacked
        ? Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [icon, const SizedBox(height: 2), label],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: OFSpacing.sm),
              label,
            ],
          );
  }
}

/// Conteneur des onglets : garde chaque onglet en vie (état, défilement) et passe
/// de l'un à l'autre en fondu enchaîné rapide.
class FadingBranches extends StatefulWidget {
  const FadingBranches({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<FadingBranches> createState() => _FadingBranchesState();
}

class _FadingBranchesState extends State<FadingBranches> {
  int? _previous;
  Timer? _timer;

  @override
  void didUpdateWidget(FadingBranches old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _previous = old.index;
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 260), () {
        if (mounted) setState(() => _previous = null);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = OFMotion.of(context).standard;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final (i, child) in widget.children.indexed)
          Offstage(
            // Onglets inactifs hors écran (aucun rendu), sauf celui qui s'efface.
            offstage: i != widget.index && i != _previous,
            child: TickerMode(
              enabled: i == widget.index,
              child: IgnorePointer(
                ignoring: i != widget.index,
                child: AnimatedOpacity(
                  opacity: i == widget.index ? 1 : 0,
                  duration: duration,
                  curve: OFMotion.standardCurve,
                  child: child,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
