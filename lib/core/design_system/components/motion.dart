import 'dart:async';

import 'package:flutter/material.dart';

import '../tokens.dart';

/// Délai d'entrée échelonné : 40 ms par élément, plafonné (les éléments lointains
/// arrivent ensemble plutôt que d'attendre leur tour).
Duration staggerDelay(int index, {int max = 8}) => Duration(milliseconds: 40 * index.clamp(0, max));

/// Fenêtre d'entrée d'un écran : les [FadeSlideIn] créés pendant la première
/// seconde s'animent (arrivée du contenu) ; ceux créés après (défilement, retour
/// sur un élément recyclé) s'affichent directement — pas d'animation à chaque scroll.
class EntranceScope extends StatefulWidget {
  const EntranceScope({super.key, required this.child, this.window = const Duration(milliseconds: 900)});

  final Widget child;
  final Duration window;

  /// true si une entrée animée est permise ici (pas de scope = toujours).
  static bool allows(BuildContext context) => context.getInheritedWidgetOfExactType<_EntranceFlag>()?.active ?? true;

  @override
  State<EntranceScope> createState() => _EntranceScopeState();
}

class _EntranceScopeState extends State<EntranceScope> {
  bool _active = true;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.window, () {
      if (mounted) setState(() => _active = false);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _EntranceFlag(active: _active, child: widget.child);
}

class _EntranceFlag extends InheritedWidget {
  const _EntranceFlag({required this.active, required super.child});

  final bool active;

  // Les éléments déjà animés ne sont pas concernés : pas de reconstruction à la fermeture.
  @override
  bool updateShouldNotify(_EntranceFlag old) => false;
}

/// Apparition douce : fondu + léger glissement vers le haut, une seule fois.
///
/// Respecte « Réduire les animations » (affichage immédiat). Ne coûte rien une
/// fois terminée : l'animation se retire de l'arbre de rendu.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 16,
    this.duration = const Duration(milliseconds: 300),
    this.axis = Axis.vertical,
  });

  final Widget child;
  final Duration delay;

  /// Distance de départ (px logiques), vers le bas (ou la droite si [axis] horizontal).
  final double offset;
  final Duration duration;
  final Axis axis;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: OFMotion.emphasizedCurve);
  bool _started = false;
  Timer? _delay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!OFMotion.of(context).enabled || !EntranceScope.allows(context)) {
      _c.value = 1;
    } else if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _delay = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    child: widget.child,
    builder: (context, child) {
      final v = _t.value;
      if (v >= 1) return child!;
      final shift = (1 - v) * widget.offset;
      return Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: widget.axis == Axis.vertical ? Offset(0, shift) : Offset(shift, 0),
          child: child,
        ),
      );
    },
  );
}

/// Transition « fondu enchaîné » entre deux états (squelette → contenu, onglets de
/// recherche…) : l'ancien s'efface, le nouveau apparaît avec un très léger zoom.
class FadeThroughSwitcher extends StatelessWidget {
  const FadeThroughSwitcher({super.key, required this.child, this.duration = const Duration(milliseconds: 280)});

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final motion = OFMotion.of(context);
    return AnimatedSwitcher(
      duration: motion.enabled ? duration : Duration.zero,
      switchInCurve: OFMotion.standardCurve,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(animation), child: child),
      ),
      child: child,
    );
  }
}

/// Icône qui change d'état avec un petit rebond (favori, vu, lecture/pause…).
class AnimatedStateIcon extends StatelessWidget {
  const AnimatedStateIcon({super.key, required this.icon, this.color, this.size = 24});

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: OFMotion.of(context).standard,
    transitionBuilder: (child, animation) => ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: animation, child: child),
    ),
    child: Icon(icon, key: ValueKey(icon), color: color, size: size),
  );
}
