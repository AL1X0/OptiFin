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
    final blur = GlassBlur.enabledOf(context);
    final surface = CustomPaint(
      foregroundPainter: _RimPainter(borderRadius),
      child: DecoratedBox(
        // Voile sombre sous le reflet : lisibilité sur une image claire. Sans flou,
        // il est plus dense pour compenser.
        decoration: BoxDecoration(
          color: Color.fromRGBO(0, 0, 0, blur ? shade : (shade + 0.22).clamp(0, 0.85)),
          borderRadius: borderRadius,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
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
    );
    // Sans flou : aucune couche de découpe. Sur iOS (Flutter 3.47), un ClipRRect posé
    // au-dessus d'une vue native efface tout ce qui la chevauche (flutter/flutter#191771,
    // #193363). Les coins arrondis sont alors simplement peints par les décorations.
    if (!blur) return surface;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: surface,
      ),
    );
  }
}

/// Active ou coupe le flou des [LiquidGlass] descendants.
///
/// À couper au-dessus d'une vue native (AVPlayer sur iOS, Media3 sur Android) : iOS
/// y rend mal un flou d'arrière-plan (contenu des boutons effacé), Android l'ignore.
class GlassBlur extends InheritedWidget {
  const GlassBlur({super.key, required this.enabled, required super.child});

  final bool enabled;

  static bool enabledOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassBlur>()?.enabled ?? true;

  @override
  bool updateShouldNotify(GlassBlur old) => old.enabled != enabled;
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

/// Coins arrondis d'une image ou d'une vignette : `ClipRRect` en temps normal, simple
/// découpe rectangulaire au-dessus d'une vue native (voir [LiquidGlass]).
class RoundedClip extends StatelessWidget {
  const RoundedClip({super.key, required this.borderRadius, required this.child});

  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      GlassBlur.enabledOf(context) ? ClipRRect(borderRadius: borderRadius, child: child) : ClipRect(child: child);
}
