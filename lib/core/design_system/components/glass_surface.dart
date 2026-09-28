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

/// « Liquid glass » : verre flouté, légèrement teinté, avec un liseré spéculaire
/// (plus clair en haut à gauche, comme une lumière rasante) et un reflet interne.
///
/// Reste lisible même quand le flou ne s'applique pas (vue vidéo native Android) :
/// le voile sombre suffit seul à détacher le contenu de l'image.
///
/// Placé sous un [BackdropGroup], tous les verres d'un écran partagent une seule
/// passe de flou.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(OFRadius.pill)),
    this.padding,
    this.sigma = 18,
    this.tint,
    this.shade = 0.28,
  });

  /// Cercle (boutons ronds).
  const LiquidGlass.circle({super.key, required this.child, this.sigma = 18, this.tint, this.shade = 0.28})
    : borderRadius = const BorderRadius.all(Radius.circular(OFRadius.pill)),
      padding = null;

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double sigma;

  /// Teinte colorée (élément actif) mêlée au verre.
  final Color? tint;

  /// Opacité du voile sombre sous le reflet (0 = verre clair).
  final double shade;

  @override
  Widget build(BuildContext context) {
    final tint = this.tint;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: CustomPaint(
          foregroundPainter: _RimPainter(borderRadius),
          child: DecoratedBox(
            // Voile sombre sous le reflet : lisibilité sur une image claire.
            decoration: BoxDecoration(color: Color.fromRGBO(0, 0, 0, shade)),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: tint == null
                      ? const [Color(0x33FFFFFF), Color(0x0FFFFFFF), Color(0x1AFFFFFF)]
                      : [tint.withValues(alpha: 0.55), tint.withValues(alpha: 0.32), tint.withValues(alpha: 0.42)],
                  stops: const [0, 0.55, 1],
                ),
              ),
              child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _RimPainter extends CustomPainter {
  const _RimPainter(this.radius);

  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect).deflate(0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x73FFFFFF), Color(0x14FFFFFF), Color(0x0AFFFFFF), Color(0x40FFFFFF)],
        stops: [0, 0.35, 0.65, 1],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_RimPainter old) => old.radius != radius;
}
