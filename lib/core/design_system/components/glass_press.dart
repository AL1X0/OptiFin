import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// Réaction « verre interactif » (iOS 26) d'un bouton : au toucher il gonfle légèrement
/// avec un rebond, et un reflet suit le doigt ; au relâcher il revient en oscillant.
///
/// N'intercepte aucun geste (simple `Listener`) : le bouton garde son propre `onTap`.
/// Aucune couche de découpe (reflet peint par une décoration arrondie) : compatible avec
/// le verre natif posé sur la vidéo.
class GlassPress extends StatefulWidget {
  const GlassPress({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(OFRadius.pill)),
    this.enabled = true,
    this.scale = 1.08,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final bool enabled;

  /// Échelle au plus fort de l'appui.
  final double scale;

  @override
  State<GlassPress> createState() => _GlassPressState();
}

class _GlassPressState extends State<GlassPress> with SingleTickerProviderStateMixin {
  late final _press = AnimationController.unbounded(vsync: this);
  Alignment _touch = Alignment.center;

  /// Ressort vif et peu amorti : le verre « rebondit » comme un liquide.
  static const _spring = SpringDescription(mass: 1, stiffness: 520, damping: 17);

  void _to(double target) => _press.animateWith(SpringSimulation(_spring, _press.value, target, _press.velocity));

  void _track(Offset local) {
    final size = context.size;
    if (size == null || size.isEmpty) return;
    setState(() {
      _touch = Alignment((local.dx / size.width) * 2 - 1, (local.dy / size.height) * 2 - 1);
    });
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final animate = OFMotion.of(context).enabled;
    return Listener(
      onPointerDown: (e) {
        _track(e.localPosition);
        _to(1);
      },
      onPointerMove: (e) => _track(e.localPosition),
      onPointerUp: (_) => _to(0),
      onPointerCancel: (_) => _to(0),
      child: AnimatedBuilder(
        animation: _press,
        child: widget.child,
        builder: (context, child) {
          final v = _press.value;
          final glow = v.clamp(0.0, 1.0);
          final content = Stack(
            clipBehavior: Clip.none,
            children: [
              child!,
              if (glow > 0.01)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: widget.borderRadius,
                        gradient: RadialGradient(
                          center: _touch,
                          radius: 1.1,
                          colors: [
                            Color.fromRGBO(255, 255, 255, 0.24 * glow),
                            Color.fromRGBO(255, 255, 255, 0.06 * glow),
                            const Color(0x00FFFFFF),
                          ],
                          stops: const [0, 0.5, 1],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
          if (!animate) return content;
          return Transform.scale(scale: 1 + (widget.scale - 1) * v, child: content);
        },
      ),
    );
  }
}
