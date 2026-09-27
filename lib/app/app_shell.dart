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

/// Coquille de navigation : barre d'onglets en verre (téléphone) ou rail latéral
/// (tablette ≥ 840 px). Le contenu défile sous la barre (extendBody).
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
    final wide = MediaQuery.sizeOf(context).width >= 840;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _SideRail(current: shell.currentIndex, onSelect: _select),
            Expanded(child: shell),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(i == current ? tab.selectedIcon : tab.icon,
                              size: 24, color: i == current ? accent : OFColors.textSecondary),
                          const SizedBox(height: 2),
                          Text(
                            tab.label,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: 88,
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
                      width: 88,
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
                            child: Icon(i == current ? tab.selectedIcon : tab.icon,
                                color: i == current ? accent : OFColors.textSecondary),
                          ),
                          const SizedBox(height: OFSpacing.xs),
                          Text(tab.label,
                              style: OFTypography.caption.copyWith(color: i == current ? accent : OFColors.textSecondary)),
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
