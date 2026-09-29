import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// Élément atteignable à la télécommande (ou au clavier) : flèches pour y aller, OK pour
/// l'activer. Quand le focus vient de la télécommande, l'élément grossit légèrement et
/// s'entoure d'un liseré lumineux ; au toucher, rien ne change (téléphones inchangés).
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    super.key,
    required this.child,
    this.onSelect,
    this.borderRadius = const BorderRadius.all(Radius.circular(OFRadius.pill)),
    this.scale = 1.06,
    this.autofocus = false,
    this.focusNode,
    this.onKeyEvent,
    this.ring = true,
    this.onFocusChange,
  });

  final Widget child;
  final VoidCallback? onSelect;
  final BorderRadius borderRadius;
  final double scale;
  final bool autofocus;
  final FocusNode? focusNode;

  /// Touches propres à l'élément (ex. gauche/droite sur la barre de progression).
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;

  /// Liseré autour de l'élément (false : zoom seul, l'élément dessine lui-même son focus).
  final bool ring;
  final ValueChanged<bool>? onFocusChange;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    final motion = OFMotion.of(context);
    final select = widget.onSelect;
    final Widget child = AnimatedScale(
      scale: _highlighted ? widget.scale : 1,
      duration: motion.fast,
      curve: OFMotion.standardCurve,
      child: widget.ring
          ? AnimatedContainer(
              duration: motion.fast,
              foregroundDecoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                border: Border.all(
                  color: _highlighted ? const Color(0xE6FFFFFF) : const Color(0x00FFFFFF),
                  width: 2.5,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
              ),
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                boxShadow: [
                  if (_highlighted) const BoxShadow(color: Color(0x40FFFFFF), blurRadius: 24, spreadRadius: 1),
                ],
              ),
              child: widget.child,
            )
          : widget.child,
    );
    final detector = FocusableActionDetector(
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      enabled: select != null || widget.onKeyEvent != null,
      actions: {
        if (select != null)
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              HapticFeedback.selectionClick();
              select();
              return null;
            },
          ),
      },
      onShowFocusHighlight: (v) {
        if (v != _highlighted) setState(() => _highlighted = v);
      },
      onFocusChange: widget.onFocusChange,
      child: child,
    );
    // Les touches remontent du nœud focalisé vers ses ancêtres : le gestionnaire se place
    // au-dessus du détecteur.
    final onKey = widget.onKeyEvent;
    if (onKey == null) return detector;
    return Focus(onKeyEvent: onKey, skipTraversal: true, canRequestFocus: false, child: detector);
  }
}
