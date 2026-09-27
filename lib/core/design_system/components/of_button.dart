import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../tokens.dart';
import 'glass_surface.dart';

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
  });

  const OFButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
  }) : variant = OFButtonVariant.secondary;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final OFButtonVariant variant;
  final bool loading;
  final bool expand;

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
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
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
      child: GestureDetector(
        onTapDown: _enabled ? (_) => _setPressed(true) : null,
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: _enabled ? _handleTap : null,
        child: AnimatedOpacity(
          duration: motion.fast,
          opacity: _enabled || widget.loading ? 1 : 0.4,
          child: AnimatedScale(
            duration: motion.fast,
            curve: OFMotion.fastCurve,
            scale: _pressed ? 0.96 : 1,
            child: body,
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
        child: GestureDetector(
          onTap: onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                },
          child: SizedBox.square(
            dimension: 44,
            child: GlassSurface(
              borderRadius: const BorderRadius.all(Radius.circular(22)),
              child: Center(child: Icon(icon, size: 20, color: OFColors.textPrimary)),
            ),
          ),
        ),
      ),
    );
  }
}
