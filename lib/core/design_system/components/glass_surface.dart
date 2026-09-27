import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// Verre dépoli borné (barres, sheets). Ne jamais l'étendre à une zone qui défile
/// en plein écran : le flou est recalculé à chaque frame.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = OFRadius.lgAll,
    this.padding,
    this.sigma = 24,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: OFColors.surfaceGlass,
            borderRadius: borderRadius,
            border: Border.all(color: OFColors.stroke, width: 0.5),
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}
