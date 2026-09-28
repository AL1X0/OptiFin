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

/// Coquille de navigation : barre d'onglets en verre (téléphone, même en paysage)
/// ou rail latéral (tablette ≥ 840 px de large). Le contenu défile sous la barre (extendBody).
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
    final mq = MediaQuery.of(context);
    // Téléphone en paysage : on garde la barre du bas (le rail est réservé aux tablettes).
    final wide = mq.size.shortestSide >= 600 && mq.size.width >= 840;
    if (wide) {
      // Le rail absorbe l'encoche gauche ; le contenu reçoit sa vraie largeur pour
      // que grilles et carrousel se dimensionnent sur l'espace réellement disponible.
      final railWidth = _SideRail.baseWidth + mq.padding.left;
      return Scaffold(
        body: Row(
          children: [
            _SideRail(current: shell.currentIndex, onSelect: _select, width: railWidth),
            Expanded(
              child: MediaQuery(
                data: mq.copyWith(
                  size: Size(mq.size.width - railWidth, mq.size.height),
                  padding: mq.padding.copyWith(left: 0),
                  viewPadding: mq.viewPadding.copyWith(left: 0),
                ),
                child: shell,
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: _GlassTabBar(current: shell.currentIndex, onSelect: _select),
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

class _SideRail extends StatelessWidget {
  const _SideRail({required this.current, required this.onSelect, required this.width});

  static const baseWidth = 96.0;

  final int current;
  final ValueChanged<int> onSelect;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: OFColors.background,
        border: Border(right: BorderSide(color: OFColors.stroke, width: 0.5)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: OFSpacing.xl),
            for (final (i, tab) in _tabs.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: OFSpacing.sm),
                child: Semantics(
                  selected: i == current,
                  button: true,
                  label: tab.label,
                  excludeSemantics: true,
                  onTap: () => onSelect(i),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(i),
                    child: SizedBox(
                      width: baseWidth,
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: OFMotion.of(context).fast,
                            width: 56,
                            height: 32,
                            decoration: BoxDecoration(
                              color: i == current ? accent.withValues(alpha: 0.18) : Colors.transparent,
                              borderRadius: const BorderRadius.all(Radius.circular(OFRadius.pill)),
                            ),
                            child: Icon(
                              i == current ? tab.selectedIcon : tab.icon,
                              color: i == current ? accent : OFColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: OFSpacing.xs),
                          Text(
                            tab.label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: OFTypography.caption.copyWith(
                              fontSize: 11,
                              color: i == current ? accent : OFColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
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
