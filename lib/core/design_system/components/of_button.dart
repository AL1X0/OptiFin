import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../tokens.dart';
import 'glass_press.dart';
import 'glass_surface.dart';
import 'tv_focus.dart';

enum OFButtonVariant { primary, secondary }

/// Bouton OptiFin : pill h48, léger scale au press + haptique.
class OFButton extends StatefulWidget {
  const OFButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = OFButtonVariant.primary,
    this.loading = false,
    this.expand = false,
    this.autofocus = false,
    this.focusNode,
  });

  const OFButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.autofocus = false,
    this.focusNode,
  }) : variant = OFButtonVariant.secondary;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final OFButtonVariant variant;
  final bool loading;
  final bool expand;

  /// Reçoit le focus à l'ouverture de l'écran (télécommande).
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<OFButton> createState() => _OFButtonState();
}

class _OFButtonState extends State<OFButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onPressed!();
  }

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final motion = OFMotion.of(context);
    final primary = widget.variant == OFButtonVariant.primary;
    final fg = primary ? OFColors.background : OFColors.textPrimary;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        else if (widget.icon != null)
          Icon(widget.icon, size: 20, color: fg),
        if (widget.loading || widget.icon != null) const SizedBox(width: OFSpacing.sm),
        Flexible(
          child: Text(
            widget.label,
            style: OFTypography.headline.copyWith(color: fg),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    const radius = BorderRadius.all(Radius.circular(OFRadius.pill));
    final padded = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: OFSpacing.xl, vertical: OFSpacing.md),
        child: content,
      ),
    );

    final body = primary
        ? DecoratedBox(
            decoration: const BoxDecoration(color: OFColors.textPrimary, borderRadius: radius),
            child: padded,
          )
        : GlassSurface(borderRadius: radius, child: padded);

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      excludeSemantics: true,
      onTap: _enabled ? _handleTap : null,
      child: TvFocusable(
        onSelect: _enabled ? _handleTap : null,
        autofocus: widget.autofocus,
        focusNode: widget.focusNode,
        borderRadius: radius,
        child: GestureDetector(
          onTapDown: _enabled ? (_) => _setPressed(true) : null,
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          onTap: _enabled ? _handleTap : null,
          child: AnimatedOpacity(
            duration: motion.fast,
            opacity: _enabled || widget.loading ? 1 : 0.4,
            child: primary
                ? AnimatedScale(
                    duration: motion.fast,
                    curve: OFMotion.fastCurve,
                    scale: _pressed ? 0.96 : 1,
                    child: body,
                  )
                // Bouton en verre : il gonfle et s'illumine sous le doigt.
                : GlassPress(borderRadius: radius, enabled: _enabled, child: body),
          ),
        ),
      ),
    );
  }
}

/// Bouton icône circulaire (zone tactile 44).
class OFIconButton extends StatelessWidget {
  const OFIconButton({super.key, required this.icon, required this.onPressed, required this.tooltip});

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: TvFocusable(
          onSelect: onPressed,
          scale: 1.12,
          child: GestureDetector(
            onTap: onPressed == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onPressed!();
                  },
            child: SizedBox.square(
              dimension: 44,
              child: GlassPress(
                enabled: onPressed != null,
                scale: 1.12,
                child: GlassSurface(
                  borderRadius: const BorderRadius.all(Radius.circular(22)),
                  child: Center(child: Icon(icon, size: 20, color: OFColors.textPrimary)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton « liquid glass » : rond (icône seule) ou pilule (icône + libellé),
/// léger rétrécissement au toucher et retour haptique.
class OFGlassButton extends StatefulWidget {
  const OFGlassButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 44,
    this.iconSize,
    this.showLabel = false,
    this.child,
  });

  final IconData icon;

  /// Libellé d'accessibilité (et texte affiché si [showLabel]).
  final String label;
  final VoidCallback? onPressed;

  /// Diamètre (ou hauteur de la pilule).
  final double size;
  final double? iconSize;
  final bool showLabel;

  /// Contenu à la place de l'icône (indicateur de chargement…).
  final Widget? child;

  @override
  State<OFGlassButton> createState() => _OFGlassButtonState();
}

class _OFGlassButtonState extends State<OFGlassButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final motion = OFMotion.of(context);
    final enabled = widget.onPressed != null;
    final icon =
        widget.child ?? Icon(widget.icon, size: widget.iconSize ?? widget.size * 0.5, color: OFColors.textPrimary);
    final body = widget.showLabel
        ? LiquidGlass(
            child: SizedBox(
              height: widget.size,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.size * 0.42),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    const SizedBox(width: OFSpacing.sm),
                    Text(widget.label, style: OFTypography.headline),
                  ],
                ),
              ),
            ),
          )
        : SizedBox.square(
            dimension: widget.size,
            child: LiquidGlass.circle(child: Center(child: icon)),
          );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      onTap: enabled ? widget.onPressed : null,
      child: TvFocusable(
        onSelect: widget.onPressed,
        scale: widget.showLabel ? 1.06 : 1.12,
        child: GestureDetector(
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  widget.onPressed!();
                }
              : null,
          child: GlassPress(
            enabled: enabled,
            scale: widget.showLabel ? 1.06 : 1.12,
            child: AnimatedOpacity(duration: motion.fast, opacity: enabled ? 1 : 0.4, child: body),
          ),
        ),
      ),
    );
  }
}
