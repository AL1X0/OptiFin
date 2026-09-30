import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:optifin_native_player/optifin_native_player.dart' show NativeGlassView;

import '../core/design_system/design_system.dart';
import '../features/settings/presentation/app_update_button.dart';
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
    if (OFDevice.desktop) return _DesktopShell(shell: shell);
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: _FloatingTabBar(current: shell.currentIndex, onSelect: _select),
    );
  }
}

/// Coquille ordinateur : barre latérale permanente, comme les applis de streaming sur PC.
/// Libellés visibles dès que la fenêtre est assez large, icônes seules sinon.
///
/// Raccourcis : Ctrl+F (recherche), Alt+← ou bouton « précédent » de la souris (retour).
class _DesktopShell extends StatelessWidget {
  const _DesktopShell({required this.shell});

  final StatefulNavigationShell shell;

  static const _items = <(int?, String, IconData, IconData)>[
    (0, 'Accueil', Icons.home_outlined, Icons.home_rounded),
    (1, 'Bibliothèques', Icons.video_library_outlined, Icons.video_library_rounded),
    (2, 'Recherche', Icons.search_rounded, Icons.search_rounded),
  ];

  void _open(int branch) => shell.goBranch(branch, initialLocation: branch == shell.currentIndex);

  void _back(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final accent = Theme.of(context).colorScheme.primary;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () => _open(2),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () => _back(context),
        const SingleActivator(LogicalKeyboardKey.browserBack): () => _back(context),
      },
      child: Listener(
        // Bouton « précédent » des souris à 5 boutons.
        onPointerDown: (e) {
          if (e.buttons & kBackMouseButton != 0) _back(context);
        },
        child: Scaffold(
          body: Row(
            children: [
              AnimatedContainer(
                duration: OFMotion.of(context).standard,
                curve: OFMotion.standardCurve,
                width: wide ? 232 : 76,
                decoration: const BoxDecoration(
                  color: Color(0xFF0B0B0D),
                  border: Border(right: BorderSide(color: Color(0x14FFFFFF))),
                ),
                padding: const EdgeInsets.fromLTRB(OFSpacing.md, OFSpacing.lg, OFSpacing.md, OFSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 0, OFSpacing.xl),
                      child: Text(
                        wide ? 'OptiFin' : 'O',
                        style: OFTypography.title1.copyWith(color: accent, letterSpacing: -0.5),
                      ),
                    ),
                    for (final (branch, label, icon, selectedIcon) in _items)
                      _SideItem(
                        icon: branch == shell.currentIndex ? selectedIcon : icon,
                        label: label,
                        wide: wide,
                        selected: branch == shell.currentIndex,
                        accent: accent,
                        onTap: () => _open(branch!),
                      ),
                    const Spacer(),
                    AppUpdateButton(wide: wide),
                    _SideItem(
                      icon: Icons.settings_outlined,
                      label: 'Réglages',
                      wide: wide,
                      selected: false,
                      accent: accent,
                      onTap: () => context.push(Routes.settings),
                    ),
                  ],
                ),
              ),
              // Les pages se mettent en page sur la zone de contenu, pas sur la fenêtre entière.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(size: constraints.biggest),
                    child: shell,
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

class _SideItem extends StatefulWidget {
  const _SideItem({
    required this.icon,
    required this.label,
    required this.wide,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool wide;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_SideItem> createState() => _SideItemState();
}

class _SideItemState extends State<_SideItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.selected ? OFColors.textPrimary : (_hovered ? OFColors.textPrimary : OFColors.textSecondary);
    final item = Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: OFMotion.of(context).fast,
            height: 44,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: widget.selected
                  ? const Color(0x1FFFFFFF)
                  : (_hovered ? const Color(0x0FFFFFFF) : const Color(0x00FFFFFF)),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            // Contenu à sa taille finale pendant l'animation de la barre (rogné, jamais tassé).
            child: ClipRect(
              child: OverflowBox(
                alignment: widget.wide ? Alignment.centerLeft : Alignment.center,
                minWidth: 0,
                maxWidth: widget.wide ? 200 : 44,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.wide ? 12 : 0),
                  child: Row(
                    mainAxisAlignment: widget.wide ? MainAxisAlignment.start : MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, size: 22, color: widget.selected ? widget.accent : fg),
                      if (widget.wide) ...[
                        const SizedBox(width: OFSpacing.md),
                        Expanded(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OFTypography.callout.copyWith(
                              color: fg,
                              fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return widget.wide ? item : Tooltip(message: widget.label, child: item);
  }
}

/// Coquille TV, comme les grandes applis de streaming sur Android TV : un menu vertical à
/// gauche, réduit à ses icônes, qui se déploie avec les libellés quand on y entre.
///
/// - ◀ au bord gauche d'une page, ou Retour sur une page racine : on entre dans le menu ;
/// - ▲ ▼ dans le menu : on passe d'une rubrique à l'autre, **sans** l'ouvrir (rien ne
///   change à l'écran tant qu'on n'a pas appuyé sur OK) ;
/// - OK ouvre la rubrique ; ▶ ou Retour revient dans la page, là où l'on était.
///
/// Menu et page ont chacun leur portée de focus : les flèches ne sautent jamais de l'un à
/// l'autre par hasard.
class _TvShell extends StatefulWidget {
  const _TvShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  State<_TvShell> createState() => _TvShellState();
}

/// Rubriques du menu TV : index de branche, ou null pour les Réglages (écran à part).
const _tvItems = <(int?, String, IconData, IconData)>[
  (2, 'Recherche', Icons.search_rounded, Icons.search_rounded),
  (0, 'Accueil', Icons.home_outlined, Icons.home_rounded),
  (1, 'Bibliothèques', Icons.video_library_outlined, Icons.video_library_rounded),
  (null, 'Réglages', Icons.settings_outlined, Icons.settings_rounded),
];

class _TvShellState extends State<_TvShell> {
  final _content = FocusScopeNode(debugLabel: 'page');
  final _menu = FocusScopeNode(debugLabel: 'menu');
  final _items = List.generate(_tvItems.length, (i) => FocusNode(debugLabel: 'menu $i'));
  bool _open = false;

  /// Retour consommé à l'appui (Android déclenche le retour au relâchement de la touche).
  bool _backDown = false;

  static const collapsed = 76.0;
  static const expanded = 248.0;

  @override
  void initState() {
    super.initState();
    _menu.addListener(_onMenuFocus);
  }

  @override
  void dispose() {
    _menu.removeListener(_onMenuFocus);
    _content.dispose();
    _menu.dispose();
    for (final n in _items) {
      n.dispose();
    }
    super.dispose();
  }

  void _onMenuFocus() {
    if (_menu.hasFocus != _open) setState(() => _open = _menu.hasFocus);
  }

  int get _currentItem => _tvItems.indexWhere((t) => t.$1 == widget.shell.currentIndex).clamp(0, _tvItems.length - 1);

  void _enterMenu() => _items[_currentItem].requestFocus();

  /// Retour dans la page : sur l'élément qui avait le focus, sinon sur le premier.
  void _enterContent() {
    FocusNode? target = _content.focusedChild;
    while (target is FocusScopeNode && target.focusedChild != null) {
      target = target.focusedChild;
    }
    if (target != null && target is! FocusScopeNode && target.context != null && target.canRequestFocus) {
      target.requestFocus();
      return;
    }
    final scope = target is FocusScopeNode ? target : _content;
    scope.requestFocus();
    if (!scope.nextFocus()) _content.nextFocus();
  }

  void _select(int item) {
    final branch = _tvItems[item].$1;
    if (branch == null) {
      unawaited(context.push(Routes.settings));
      return;
    }
    widget.shell.goBranch(branch, initialLocation: branch == widget.shell.currentIndex);
    // La page s'ouvre avec le focus sur son premier élément.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _content.requestFocus();
      _content.nextFocus();
    });
  }

  static bool _isBack(KeyEvent e) =>
      e.logicalKey == LogicalKeyboardKey.goBack || e.logicalKey == LogicalKeyboardKey.escape;

  KeyEventResult _fromContent(FocusNode node, KeyEvent event) {
    if (_isBack(event)) {
      if (event is KeyDownEvent) {
        // Page racine (rien à dépiler) : Retour mène au menu au lieu de quitter l'appli.
        _backDown = !GoRouter.of(context).canPop();
        if (_backDown) _enterMenu();
      }
      return _backDown ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final primary = FocusManager.instance.primaryFocus;
    // Focus perdu dans la page (élément disparu) : la flèche le rend à la page.
    if (primary == null || primary is FocusScopeNode) {
      _enterContent();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (primary.focusInDirection(TraversalDirection.left)) return KeyEventResult.handled;
      _enterMenu();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _fromMenu(FocusNode node, KeyEvent event) {
    if (_isBack(event)) {
      // Retour depuis le menu : vers l'Accueil ; depuis l'Accueil, on quitte l'appli.
      if (event is KeyDownEvent) {
        _backDown = widget.shell.currentIndex != 0;
        if (_backDown) _select(_tvItems.indexWhere((t) => t.$1 == 0));
      }
      return _backDown ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _enterContent();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final motion = OFMotion.of(context);
    final accent = Theme.of(context).colorScheme.primary;
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
                // Les pages s'écartent du menu réduit (et des bords rognés des téléviseurs).
                data: mq.copyWith(
                  padding: mq.padding.copyWith(left: mq.padding.left + collapsed, top: mq.padding.top + OFSpacing.md),
                  viewPadding: mq.viewPadding.copyWith(
                    left: mq.viewPadding.left + collapsed,
                    top: mq.viewPadding.top + OFSpacing.md,
                  ),
                ),
                child: widget.shell,
              ),
            ),
          ),
          // Voile derrière le menu déployé.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _open ? 1 : 0,
                duration: motion.standard,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xF2000000), Color(0xB3000000), Color(0x00000000)],
                      stops: [0, 0.3, 0.6],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: _fromMenu,
              child: FocusScope(
                node: _menu,
                child: AnimatedContainer(
                  duration: motion.standard,
                  curve: OFMotion.standardCurve,
                  width: _open ? expanded : collapsed,
                  padding: EdgeInsets.fromLTRB(OFSpacing.md, mq.padding.top + OFSpacing.xl, OFSpacing.md, OFSpacing.xl),
                  // Réduit : fine bande sombre, les icônes restent lisibles sur l'image.
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Color(_open ? 0x00000000 : 0x8C000000), const Color(0x00000000)]),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      for (final (i, (branch, label, icon, selectedIcon)) in _tvItems.indexed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: _TvMenuItem(
                            icon: branch == widget.shell.currentIndex ? selectedIcon : icon,
                            label: label,
                            selected: branch == widget.shell.currentIndex,
                            expanded: _open,
                            accent: accent,
                            focusNode: _items[i],
                            onSelect: () => _select(i),
                          ),
                        ),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rubrique du menu TV : icône seule (menu réduit) ou icône et libellé (menu déployé) ;
/// pilule blanche au focus, icône colorée pour la rubrique ouverte.
class _TvMenuItem extends StatefulWidget {
  const _TvMenuItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.accent,
    required this.focusNode,
    required this.onSelect,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final Color accent;
  final FocusNode focusNode;
  final VoidCallback onSelect;

  @override
  State<_TvMenuItem> createState() => _TvMenuItemState();
}

class _TvMenuItemState extends State<_TvMenuItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final motion = OFMotion.of(context);
    final fg = _focused ? OFColors.background : (widget.selected ? widget.accent : OFColors.textSecondary);
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      child: TvFocusable(
        ring: false,
        scale: 1.04,
        focusNode: widget.focusNode,
        onSelect: widget.onSelect,
        onFocusChange: (f) => setState(() => _focused = f),
        child: GestureDetector(
          onTap: widget.onSelect,
          child: AnimatedContainer(
            duration: motion.fast,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _focused ? OFColors.textPrimary : const Color(0x00FFFFFF),
              borderRadius: const BorderRadius.all(Radius.circular(OFRadius.pill)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 24, color: fg),
                if (widget.expanded)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: OFSpacing.md, right: OFSpacing.sm),
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: OFTypography.headline.copyWith(
                          color: _focused ? OFColors.background : OFColors.textPrimary,
                          fontWeight: widget.selected || _focused ? FontWeight.w600 : FontWeight.w500,
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
              // Onglets inactifs hors d'atteinte de la télécommande (sinon le focus pouvait
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
