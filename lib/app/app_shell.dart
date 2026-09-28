import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

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
];

/// Coquille de navigation : barre d'onglets en verre pleine largeur (téléphone) ou
/// pilule flottante (tablette). Le contenu défile sous la barre (extendBody).
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
    // Tablette (portrait comme paysage) : barre flottante ; téléphone : barre pleine largeur.
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: tablet
          ? _FloatingTabBar(current: shell.currentIndex, onSelect: _select)
          : _GlassTabBar(current: shell.currentIndex, onSelect: _select),
    );
  }
}

class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final accent = Theme.of(context).colorScheme.primary;
    return GlassSurface(
      borderRadius: BorderRadius.zero,
      child: ColoredBox(
        color: const Color(0x99000000),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom > 0 ? bottom - OFSpacing.xs : OFSpacing.sm, top: OFSpacing.sm),
          child: Row(
            children: [
              for (final (i, tab) in _tabs.indexed)
                Expanded(
                  child: Semantics(
                    selected: i == current,
                    button: true,
                    label: tab.label,
                    excludeSemantics: true,
                    onTap: () => onSelect(i),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(i),
                      child: _TabItem(tab: tab, selected: i == current, accent: accent),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tablette : barre d'onglets flottante en verre, centrée en bas (icône + libellé
/// côte à côte). Le contenu garde toute la largeur de l'écran.
class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final accent = Theme.of(context).colorScheme.primary;
    final motion = OFMotion.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: bottom > 0 ? bottom : OFSpacing.lg, top: OFSpacing.sm),
      child: Center(
        heightFactor: 1,
        child: LiquidGlass(
          shade: 0.45,
          sigma: 24,
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
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: OFSpacing.lg + 2),
                      decoration: BoxDecoration(
                        color: i == current ? const Color(0x24FFFFFF) : const Color(0x00FFFFFF),
                        borderRadius: const BorderRadius.all(Radius.circular(OFRadius.pill)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedStateIcon(
                            icon: i == current ? tab.selectedIcon : tab.icon,
                            color: i == current ? accent : OFColors.textSecondary,
                          ),
                          const SizedBox(width: OFSpacing.sm),
                          AnimatedDefaultTextStyle(
                            duration: motion.standard,
                            style: DefaultTextStyle.of(context).style.merge(
                              OFTypography.callout.copyWith(
                                color: i == current ? OFColors.textPrimary : OFColors.textSecondary,
                                fontWeight: i == current ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                            child: Text(tab.label),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
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

/// Onglet de la barre du bas : l'onglet actif grossit légèrement, couleur et icône en fondu.
class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab, required this.selected, required this.accent});

  final _Tab tab;
  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final motion = OFMotion.of(context);
    final color = selected ? accent : OFColors.textSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedScale(
          scale: selected ? 1.12 : 1,
          duration: motion.standard,
          curve: Curves.easeOutBack,
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: color),
            duration: motion.standard,
            builder: (context, c, _) => AnimatedStateIcon(icon: selected ? tab.selectedIcon : tab.icon, color: c),
          ),
        ),
        const SizedBox(height: 2),
        AnimatedDefaultTextStyle(
          duration: motion.standard,
          // Fusion avec le style hérité : garde la police du thème (système sur iOS).
          style: DefaultTextStyle.of(context).style.merge(OFTypography.caption.copyWith(fontSize: 11, color: color)),
          child: Text(tab.label),
        ),
      ],
    );
  }
}
