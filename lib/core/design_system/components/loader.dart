import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens.dart';
import 'glass_surface.dart';

/// Indicateur de chargement OptiFin : un arc fin en dégradé (traînée de comète)
/// qui tourne, dont la longueur respire. Reste animé même avec « Réduire les
/// animations » : c'est un signal d'attente, pas une décoration.
class OFLoader extends StatefulWidget {
  const OFLoader({super.key, this.size = 32, this.strokeWidth = 3, this.color = OFColors.textPrimary});

  /// Posé sur une pastille de verre (lecteur, au-dessus d'une image).
  static Widget glass({double size = 64}) => SizedBox.square(
    dimension: size,
    child: LiquidGlass.circle(
      child: Center(child: OFLoader(size: size * 0.46, strokeWidth: 2.5)),
    ),
  );

  final double size;
  final double strokeWidth;
  final Color color;

  @override
  State<OFLoader> createState() => _OFLoaderState();
}

class _OFLoaderState extends State<OFLoader> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chargement',
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(
            painter: _ArcPainter(_controller, color: widget.color, strokeWidth: widget.strokeWidth),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.animation, {required this.color, required this.strokeWidth}) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final center = rect.center;

    // Piste très discrète.
    canvas.drawCircle(
      center,
      rect.width / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color.withValues(alpha: 0.12),
    );

    // Longueur de l'arc : 90° → 250° → 90° (respiration), rotation continue.
    final breathe = Curves.easeInOut.transform(t < 0.5 ? t * 2 : (1 - t) * 2);
    final sweep = (0.25 + 0.45 * breathe) * 2 * math.pi;
    final start = t * 2 * math.pi * 2 - math.pi / 2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(start);
    canvas.translate(-center.dx, -center.dy);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0), color],
        stops: [0, sweep / (2 * math.pi)],
      ).createShader(rect);
    canvas.drawArc(rect, 0, sweep, false, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color || old.strokeWidth != strokeWidth;
}
