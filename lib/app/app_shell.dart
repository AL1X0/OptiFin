import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
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

/// Pilule flottante façon iOS 26 : l'onglet actif est une « lentille » de verre qui glisse
/// d'un onglet à l'autre avec un ressort, s'étire avec la vitesse et grossit ce qu'elle
/// survole. On peut aussi la faire glisser du doigt : relâchée, elle se pose sur l'onglet
/// le plus proche. Icône au-dessus du libellé sur téléphone, côte à côte sur tablette.
class _FloatingTabBar extends StatefulWidget {
  const _FloatingTabBar({required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  @override
  State<_FloatingTabBar> createState() => _FloatingTabBarState();
}

class _FloatingTabBarState extends State<_FloatingTabBar> with SingleTickerProviderStateMixin {
  /// Position de la lentille, en onglets (0 = premier onglet).
  late final _lens = AnimationController.unbounded(vsync: this, value: widget.current.toDouble());
  bool _dragging = false;

  /// Ressort peu amorti : léger dépassement, comme une goutte qui se pose.
  static const _spring = SpringDescription(mass: 1, stiffness: 320, damping: 21);
  static const _pad = 5.0;

  @override
  void didUpdateWidget(_FloatingTabBar old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current && !_dragging) _moveTo(widget.current.toDouble());
  }

  @override
  void dispose() {
    _lens.dispose();
    super.dispose();
  }

  void _moveTo(double target, {double? velocity}) {
    if (!OFMotion.of(context).enabled) {
      _lens.value = target;
      return;
    }
    _lens.animateWith(SpringSimulation(_spring, _lens.value, target, velocity ?? _lens.velocity));
  }

  void _dragStart(DragStartDetails _) {
    _lens.stop();
    setState(() => _dragging = true);
    HapticFeedback.selectionClick();
  }

  void _dragUpdate(DragUpdateDetails d, double tabWidth) {
    final last = _tabs.length - 1;
    final next = (_lens.value + d.delta.dx / tabWidth).clamp(-0.2, last + 0.2);
    // Petit « clic » à chaque onglet franchi.
    if (next.round() != _lens.value.round()) HapticFeedback.selectionClick();
    _lens.value = next;
  }

  void _dragEnd(DragEndDetails d, double tabWidth) {
    final velocity = d.velocity.pixelsPerSecond.dx / tabWidth;
    // L'élan prolonge un peu le geste, comme sur iOS.
    final target = (_lens.value + velocity * 0.12).round().clamp(0, _tabs.length - 1);
    setState(() => _dragging = false);
    _moveTo(target.toDouble(), velocity: velocity);
    if (target != widget.current) widget.onSelect(target);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final accent = Theme.of(context).colorScheme.primary;
    final tablet = OFDevice.large(context);
    final tabWidth = tablet ? 168.0 : 90.0;
    final height = tablet ? 46.0 : 54.0;
    final nativeGlass = NativeGlassView.supported;

    final bar = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _dragStart,
      onHorizontalDragUpdate: (d) => _dragUpdate(d, tabWidth),
      onHorizontalDragEnd: (d) => _dragEnd(d, tabWidth),
      onHorizontalDragCancel: () => _dragEnd(DragEndDetails(), tabWidth),
      child: Padding(
        padding: const EdgeInsets.all(_pad),
        child: SizedBox(
          width: tabWidth * _tabs.length,
          height: height,
          child: AnimatedBuilder(
            animation: _lens,
            builder: (context, _) {
              final x = _lens.value;
              final moving = _lens.isAnimating ? _lens.velocity.abs() : 0.0;
              // Soulevée pendant le glissé ou le trajet : plus grande, plus claire.
              final lift = _dragging ? 1.0 : ((x - x.roundToDouble()).abs() * 3).clamp(0.0, 1.0);
              // Étirement « liquide » proportionnel à la vitesse.
              final stretch = (moving * 0.05).clamp(0.0, 0.32);
              final lensWidth = tabWidth * (1 + stretch) * (1 + 0.06 * lift);
              final lensHeight = height * (1 - stretch * 0.22) * (1 + 0.08 * lift);
              final nearest = x.round().clamp(0, _tabs.length - 1);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: x * tabWidth + (tabWidth - lensWidth) / 2,
                    top: (height - lensHeight) / 2,
                    width: lensWidth,
                    height: lensHeight,
                    child: _Lens(lift: lift),
                  ),
                  Row(
                    children: [
                      for (final (i, tab) in _tabs.indexed)
                        Semantics(
                          selected: i == widget.current,
                          button: true,
                          label: tab.label,
                          excludeSemantics: true,
                          onTap: () => widget.onSelect(i),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => widget.onSelect(i),
                            child: SizedBox(
                              width: tabWidth,
                              height: height,
                              child: Center(
                                // Effet loupe : ce que la lentille survole grossit.
                                child: Transform.scale(
                                  scale: 1 + 0.14 * lift * (1 - (i - x).abs()).clamp(0.0, 1.0),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: _TabContent(
                                        tab: tab,
                                        selected: i == nearest,
                                        accent: accent,
                                        stacked: !tablet,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    // Rétrécit plutôt que de déborder (petits écrans, grandes polices).
    final row = FittedBox(fit: BoxFit.scaleDown, child: bar);

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

/// Lentille de l'onglet actif : verre plus dense que la barre, liseré spéculaire ;
/// plus claire quand elle est soulevée (glissé, trajet).
class _Lens extends StatelessWidget {
  const _Lens({required this.lift});

  final double lift;

  static const _radius = BorderRadius.all(Radius.circular(OFRadius.pill));

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: GlassRimPainter(_radius, strength: 0.55 + 0.45 * lift),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: _radius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(255, 255, 255, 0.16 + 0.10 * lift),
              Color.fromRGBO(255, 255, 255, 0.07 + 0.06 * lift),
            ],
          ),
          boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.18 + 0.12 * lift), blurRadius: 10 + 8 * lift)],
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
          color: selected ? accent : OFColors.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      child: Text(tab.label, maxLines: 1, softWrap: false, overflow: TextOverflow.visible),
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
              // Onglets inactifs hors d’atteinte du clavier (sinon le focus pouvait
              // sauter dans une page cachée, comme le champ de la recherche).
              child: ExcludeFocus(
                excluding: i != widget.index,
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
          ),
      ],
    );
  }
}
