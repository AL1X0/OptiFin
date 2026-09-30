import 'package:flutter/material.dart';

import '../theme.dart';
import '../device.dart';
import '../tokens.dart';
import 'glass_surface.dart';
import 'motion.dart';

/// Rangée horizontale virtualisée (titre + « Tout voir »).
class MediaRow extends StatelessWidget {
  const MediaRow({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemExtent,
    required this.height,
    this.onSeeAll,
  });

  final String title;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Largeur d'un élément + espacement : permet à la liste de sauter le layout.
  final double itemExtent;
  final double height;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final gutter = OFSpacing.gutterOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 0, gutter - OFSpacing.sm, OFSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: OFTypography.title2, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: Text('Tout voir', style: OFTypography.callout.copyWith(color: OFColors.textSecondary)),
                ),
            ],
          ),
        ),
        SizedBox(
          height: height,
          child: _RowScroller(
            gutter: gutter,
            builder: (controller) => ListView.builder(
              controller: controller,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: gutter),
              itemExtent: itemExtent,
              // TV : la carte focalisée grossit et déborde sans être rognée.
              clipBehavior: OFDevice.tv ? Clip.none : Clip.hardEdge,
              itemCount: itemCount,
              // Arrivée des cartes de gauche à droite (dans la fenêtre d'entrée de l'écran).
              itemBuilder: (context, i) => Align(
                alignment: Alignment.topLeft,
                child: FadeSlideIn(
                  delay: staggerDelay(i, max: 6),
                  axis: Axis.horizontal,
                  offset: 24,
                  child: itemBuilder(context, i),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Défilement d'une rangée à la souris (ordinateur) : au survol, deux flèches en verre
/// font avancer ou reculer d'une page. Ailleurs, la liste seule (doigt, télécommande).
class _RowScroller extends StatefulWidget {
  const _RowScroller({required this.builder, required this.gutter});

  final Widget Function(ScrollController? controller) builder;
  final double gutter;

  @override
  State<_RowScroller> createState() => _RowScrollerState();
}

class _RowScrollerState extends State<_RowScroller> {
  final _controller = ScrollController();
  bool _hovered = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _page(int direction) {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    final target = (p.pixels + direction * (p.viewportDimension - widget.gutter * 2) * 0.9).clamp(
      p.minScrollExtent,
      p.maxScrollExtent,
    );
    _controller.animateTo(target, duration: const Duration(milliseconds: 420), curve: OFMotion.standardCurve);
  }

  @override
  Widget build(BuildContext context) {
    if (!OFDevice.desktop) return widget.builder(null);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        children: [
          Positioned.fill(child: widget.builder(_controller)),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final ready = _controller.hasClients && _controller.position.hasContentDimensions;
              final canBack = ready && _controller.offset > 1;
              final canForward = ready && _controller.offset < _controller.position.maxScrollExtent - 1;
              return Stack(
                children: [
                  _Arrow(visible: _hovered && canBack, left: true, inset: widget.gutter, onTap: () => _page(-1)),
                  _Arrow(visible: _hovered && canForward, left: false, inset: widget.gutter, onTap: () => _page(1)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.visible, required this.left, required this.inset, required this.onTap});

  final bool visible;
  final bool left;
  final double inset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      bottom: 0,
      left: left ? inset * 0.25 : null,
      right: left ? null : inset * 0.25,
      child: Center(
        child: IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: OFMotion.of(context).fast,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onTap,
                child: LiquidGlass(
                  shade: 0.55,
                  child: SizedBox.square(
                    dimension: 44,
                    child: Icon(
                      left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                      size: 30,
                      color: OFColors.textPrimary,
                      semanticLabel: left ? 'Précédents' : 'Suivants',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
