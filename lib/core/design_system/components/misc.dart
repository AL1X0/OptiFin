import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import 'glass_surface.dart';
import 'of_image.dart';

/// Badge qualité monochrome : 4K, HDR, DV, Atmos, DTS…
class QualityBadge extends StatelessWidget {
  const QualityBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: OFRadius.smAll,
        border: Border.all(color: OFColors.textTertiary),
      ),
      child: Text(
        label,
        style: OFTypography.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: OFColors.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Champ texte OptiFin.
class OFTextField extends StatelessWidget {
  const OFTextField({
    super.key,
    required this.label,
    this.controller,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.autofocus = false,
    this.errorText,
    this.focusNode,
  });

  final FocusNode? focusNode;

  final String label;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: OFRadius.mdAll,
      borderSide: BorderSide(color: c, width: 1),
    );
    return TextField(
      focusNode: focusNode,
      controller: controller,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: !obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      style: OFTypography.body,
      cursorColor: accent,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        filled: true,
        fillColor: OFColors.surface,
        labelStyle: OFTypography.callout.copyWith(color: OFColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: OFSpacing.lg, vertical: OFSpacing.lg),
        enabledBorder: border(OFColors.stroke),
        focusedBorder: border(accent),
        errorBorder: border(OFColors.danger),
        focusedErrorBorder: border(OFColors.danger),
      ),
    );
  }
}

/// Avatar utilisateur rond, initiales si pas d'image.
class AvatarChip extends StatelessWidget {
  const AvatarChip({super.key, required this.name, this.imageUrl, this.size = 40});

  final String name;
  final Uri? imageUrl;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final initials = Container(
      color: OFColors.surfaceRaised,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: OFTypography.headline.copyWith(fontSize: size * 0.4, color: OFColors.textSecondary),
      ),
    );
    return Semantics(
      label: name,
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: ClipOval(
          child: imageUrl == null
              ? initials
              : OFImage(url: imageUrl, decodeWidth: (size * dpr).ceil(), fallback: initials),
        ),
      ),
    );
  }
}

/// Bottom sheet en verre dépoli.
Future<T?> showOFSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x99000000),
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: GlassSurface(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(OFRadius.lg)),
          sigma: 32,
          // Material (et non ColoredBox) : les ListTile du contenu y peignent leur
          // fond et leurs effets de toucher.
          child: Material(
            color: const Color(0xB3141416),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: OFSpacing.sm),
                Container(
                  width: 36,
                  height: 4,
                  decoration: const BoxDecoration(color: OFColors.textTertiary, borderRadius: OFRadius.smAll),
                ),
                const SizedBox(height: OFSpacing.sm),
                Flexible(child: builder(context)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
