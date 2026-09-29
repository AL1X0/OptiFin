import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../tokens.dart';
import 'native_glass.dart';

/// Réglage global du verre.
abstract final class OFGlass {
  /// Flou d'arrière-plan en temps réel. Coupé sur Android : chaque `BackdropFilter`
  /// relit et floute l'image à chaque frame (barre d'onglets, boutons, en-têtes), ce qui
  /// chauffe et ralentit les téléphones Android de milieu de gamme. Le verre y reste
  /// teinté, avec liseré et reflet.
  static bool blur = defaultTargetPlatform != TargetPlatform.android;
}

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
    if (!OFGlass.blur) {
      // Sans flou : teinte dense, aucune couche de découpe ni relecture de l'image.
      return DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xE61A1A1D),
          borderRadius: borderRadius,
          border: Border.all(color: OFColors.stroke, width: 0.5),
        ),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      );
    }
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
    this.sigma = 24,
    this.tint,
    this.shade = 0.28,
    this.rim = true,
  });

  /// Cercle (boutons ronds).
  const LiquidGlass.circle({
    super.key,
    required this.child,
    this.sigma = 24,
    this.tint,
    this.shade = 0.28,
    this.rim = true,
  }) : borderRadius = const BorderRadius.all(Radius.circular(OFRadius.pill)),
       padding = null;

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double sigma;

  /// Teinte colorée (élément actif) mêlée au verre.
  final Color? tint;

  /// Opacité du voile sombre sous le reflet (0 = verre clair).
  final double shade;

  /// Liseré spéculaire (false : verre sans contour, ex. barre de progression).
  final bool rim;

  @override
  Widget build(BuildContext context) {
    final tint = this.tint;
    final blur = GlassBlur.enabledOf(context);
    // Verre natif (iOS, au-dessus d'AVPlayer) : la vue vidéo dessine le matériau ;
    // ici, seulement un liseré discret et le contenu.
    final native = NativeGlassScope.maybeOf(context);
    if (native != null) {
      return NativeGlassSlot(
        scope: native,
        borderRadius: borderRadius,
        child: CustomPaint(
          foregroundPainter: rim ? GlassRimPainter(borderRadius, strength: 0.5) : null,
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      );
    }
    final surface = CustomPaint(
      foregroundPainter: rim ? GlassRimPainter(borderRadius) : null,
      child: DecoratedBox(
        // Voile sombre sous le reflet : lisibilité sur une image claire. Sans flou,
        // il est plus dense pour compenser.
        decoration: BoxDecoration(
          // Flouté : verre clair comme celui d'Apple (voile léger) ; sans flou : plus dense.
          color: Color.fromRGBO(0, 0, 0, blur ? shade * 0.5 : (shade + 0.22).clamp(0, 0.85)),
          borderRadius: borderRadius,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: tint == null
                  ? const [Color(0x38FFFFFF), Color(0x14FFFFFF), Color(0x24FFFFFF)]
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
        // Flou + saturation relevée : les couleurs de l'image « vivent » dans le verre.
        filter: ImageFilter.compose(
          outer: _saturate,
          inner: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        ),
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
      OFGlass.blur && (context.dependOnInheritedWidgetOfExactType<GlassBlur>()?.enabled ?? true);

  @override
  bool updateShouldNotify(GlassBlur old) => old.enabled != enabled;
}

/// Liseré spéculaire façon Liquid Glass : lumière forte en haut à gauche, reflet plus
/// doux en bas à droite, presque rien sur les flancs.
class GlassRimPainter extends CustomPainter {
  const GlassRimPainter(this.radius, {this.strength = 1});

  final BorderRadius radius;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect).deflate(0.6);
    Color white(double a) => Color.fromRGBO(255, 255, 255, a * strength);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [white(0.75), white(0.12), white(0.06), white(0.5)],
        stops: const [0, 0.3, 0.7, 1],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(GlassRimPainter old) => old.radius != radius || old.strength != strength;
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

/// Saturation × 1,6 (matrice de luminance Rec. 709).
const _saturate = ColorFilter.matrix(<double>[
  1.4724, -0.4291, -0.0433, 0, 0, //
  -0.1276, 1.1709, -0.0433, 0, 0, //
  -0.1276, -0.4291, 1.5567, 0, 0, //
  0, 0, 0, 1, 0, //
]);
