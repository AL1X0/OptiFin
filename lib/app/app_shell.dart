import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:optifin_native_player/optifin_native_player.dart' show NativeGlassView;

import '../core/design_system/design_system.dart';
import 'router.dart';

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
    if (OFDevice.tv) return _TvShell(shell: shell);
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: _FloatingTabBar(current: shell.currentIndex, onSelect: _select),
    );
  }
}

/// Coquille TV : menu en pilule en haut (comme l'Apple TV) ; l'image occupe tout l'écran et
/// les pages reçoivent une marge haute pour ne pas passer sous le menu.
///
/// Chaque onglet a sa propre zone de focus : ▲ tout en haut d'une page n'y trouve rien. La
/// coquille prend alors le relais et remonte dans le menu (sur l'onglet ouvert) ; ▼ depuis
/// le menu redescend dans la page, sur l'élément qui avait le focus.
class _TvShell extends StatefulWidget {
  const _TvShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  State<_TvShell> createState() => _TvShellState();
}

class _TvShellState extends State<_TvShell> {
  final _content = FocusScopeNode(debugLabel: 'page');
  final _tabs = List.generate(4, (i) => FocusNode(debugLabel: 'onglet $i'));

  @override
  void dispose() {
    _content.dispose();
    for (final n in _tabs) {
      n.dispose();
    }
    super.dispose();
  }

  KeyEventResult _fromContent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.arrowUp) return KeyEventResult.ignored;
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || _tabs.contains(primary)) return KeyEventResult.ignored;
    if (primary.focusInDirection(TraversalDirection.up)) return KeyEventResult.handled;
    _tabs[widget.shell.currentIndex.clamp(0, 2)].requestFocus();
    return KeyEventResult.handled;
  }

  KeyEventResult _fromMenu(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.arrowDown) return KeyEventResult.ignored;
    if (!_tabs.contains(FocusManager.instance.primaryFocus)) return KeyEventResult.ignored;
    // Dernier élément focalisé de la page, sinon son premier élément.
    var target = _content.focusedChild;
    while (target is FocusScopeNode && target.focusedChild != null) {
      target = target.focusedChild;
    }
    if (target != null && target is! FocusScopeNode) {
      target.requestFocus();
    } else {
      (target as FocusScopeNode? ?? _content).nextFocus();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    const barSpace = 76.0;
    final shell = widget.shell;
    return Scaffold(
      body: Stack(
        children: [
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _fromContent,
            child: FocusScope(
              node: _content,
              child: MediaQuery(
                data: mq.copyWith(
                  padding: mq.padding.copyWith(top: mq.padding.top + barSpace),
                  viewPadding: mq.viewPadding.copyWith(top: mq.viewPadding.top + barSpace),
                ),
                child: shell,
              ),
            ),
          ),
          Positioned(
            top: mq.padding.top + OFSpacing.lg,
            left: 0,
            right: 0,
            child: Center(
              child: Focus(
                canRequestFocus: false,
                skipTraversal: true,
                onKeyEvent: _fromMenu,
                child: _TvTabBar(
                  current: shell.currentIndex,
                  focusNodes: _tabs,
                  onSelect: (i) {
                    if (i != shell.currentIndex) shell.goBranch(i);
                  },
                  onSettings: () => context.push(Routes.settings),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Menu TV : pilule de verre en haut. Poser le focus sur un onglet l'ouvre (comme sur
/// l'Apple TV) ; l'onglet focalisé passe en blanc, l'onglet ouvert garde sa pastille.
/// « Réglages » remplace « Téléchargements » (inutiles sur un téléviseur).
class _TvTabBar extends StatelessWidget {
  const _TvTabBar({required this.current, required this.onSelect, required this.onSettings, required this.focusNodes});

  final int current;
  final List<FocusNode> focusNodes;
  final ValueChanged<int> onSelect;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return LiquidGlass(
      shade: 0.5,
      padding: const EdgeInsets.all(5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, tab) in _tabs.take(3).indexed)
            _TvTab(
              icon: i == current ? tab.selectedIcon : tab.icon,
              label: tab.label,
              selected: i == current,
              accent: accent,
              focusNode: focusNodes[i],
              onFocus: () => onSelect(i),
              onSelect: () => onSelect(i),
            ),
          _TvTab(
            icon: Icons.settings_outlined,
            label: 'Réglages',
            selected: false,
            accent: accent,
            focusNode: focusNodes[3],
            onSelect: onSettings,
          ),
        ],
      ),
    );
  }
}

class _TvTab extends StatefulWidget {
  const _TvTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onSelect,
    required this.focusNode,
    this.onFocus,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onSelect;
  final VoidCallback? onFocus;
  final FocusNode focusNode;

  @override
  State<_TvTab> createState() => _TvTabState();
}

class _TvTabState extends State<_TvTab> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final motion = OFMotion.of(context);
    final fg = _focused ? OFColors.background : (widget.selected ? widget.accent : OFColors.textSecondary);
    return TvFocusable(
      ring: false,
      scale: 1.08,
      focusNode: widget.focusNode,
      onSelect: widget.onSelect,
      onFocusChange: (f) {
        setState(() => _focused = f);
        if (f) widget.onFocus?.call();
      },
      child: AnimatedContainer(
        duration: motion.fast,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: OFSpacing.lg + 2),
        decoration: BoxDecoration(
          color: _focused
              ? OFColors.textPrimary
              : (widget.selected ? const Color(0x24FFFFFF) : const Color(0x00FFFFFF)),
          borderRadius: const BorderRadius.all(Radius.circular(OFRadius.pill)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 20, color: fg),
            const SizedBox(width: OFSpacing.sm),
            Text(
              widget.label,
              style: OFTypography.callout.copyWith(
                color: fg,
                fontWeight: widget.selected || _focused ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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
