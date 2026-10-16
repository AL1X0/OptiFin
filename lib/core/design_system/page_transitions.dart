import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';

/// Transition iOS dont le retour par glissé depuis le bord gauche n'est plus « volé »
/// par les rangées qui défilent horizontalement jusqu'au bord de l'écran.
class OFCupertinoPageTransitionsBuilder extends CupertinoPageTransitionsBuilder {
  const OFCupertinoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => super.buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    _EdgeSwipeGuard(enabled: () => route.popGestureEnabled, child: child),
  );
}

/// Bande du bord gauche (même largeur que la zone du geste de retour Flutter) que la page
/// ne reçoit pas tant qu'un retour est possible : seul le geste de retour, posé au-dessus
/// de la page, voit le toucher et ne perd plus l'arène contre un défilement horizontal.
class _EdgeSwipeGuard extends SingleChildRenderObjectWidget {
  const _EdgeSwipeGuard({required this.enabled, required super.child});

  final bool Function() enabled;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderEdgeSwipeGuard(enabled, _width(context));

  @override
  void updateRenderObject(BuildContext context, _RenderEdgeSwipeGuard renderObject) => renderObject
    ..enabled = enabled
    ..width = _width(context);

  static double _width(BuildContext context) => math.max(MediaQuery.paddingOf(context).left, 20);
}

class _RenderEdgeSwipeGuard extends RenderProxyBox {
  _RenderEdgeSwipeGuard(this.enabled, this.width);

  bool Function() enabled;
  double width;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // Le test de contact a lieu entre deux images : popGestureEnabled peut y être lu.
    if (position.dx >= 0 && position.dx < width && size.contains(position) && enabled()) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return super.hitTest(result, position: position);
  }
}
