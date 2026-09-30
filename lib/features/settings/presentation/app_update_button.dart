import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/providers.dart';
import '../data/app_updater.dart';

final appUpdaterProvider = Provider<AppUpdater>((ref) => AppUpdater());

/// Version plus récente publiée (ordinateur seulement, vérifiée une fois au lancement).
final availableUpdateProvider = FutureProvider<AppUpdate?>((ref) async {
  if (!OFDevice.desktop || kDebugMode) return null;
  return ref.read(appUpdaterProvider).check(ref.read(clientIdentityProvider).version);
});

/// Bouton de la barre latérale (ordinateur), visible seulement quand une mise à jour existe.
class AppUpdateButton extends ConsumerWidget {
  const AppUpdateButton({super.key, required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(availableUpdateProvider).value;
    if (update == null) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    final button = Semantics(
      button: true,
      label: 'Mettre à jour vers la version ${update.version}',
      excludeSemantics: true,
      child: TvFocusable(
        ring: false,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        onSelect: () => _confirm(context, ref, update),
        child: GestureDetector(
          onTap: () => _confirm(context, ref, update),
          child: Container(
            height: 44,
            margin: const EdgeInsets.only(bottom: OFSpacing.sm),
            padding: EdgeInsets.symmetric(horizontal: wide ? 12 : 0),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: wide ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(Icons.system_update_alt_rounded, size: 22, color: accent),
                if (wide) ...[
                  const SizedBox(width: OFSpacing.md),
                  Expanded(
                    child: Text(
                      'Mise à jour ${update.version}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OFTypography.callout.copyWith(color: accent, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return wide ? button : Tooltip(message: 'Mise à jour ${update.version}', child: button);
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref, AppUpdate update) =>
      showDialog<void>(context: context, builder: (_) => _UpdateDialog(update: update));
}

class _UpdateDialog extends ConsumerStatefulWidget {
  const _UpdateDialog({required this.update});

  final AppUpdate update;

  @override
  ConsumerState<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<_UpdateDialog> {
  double? _progress;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      await ref
          .read(appUpdaterProvider)
          .install(
            widget.update,
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
    } catch (e) {
      if (mounted) {
        setState(() {
          _progress = null;
          _error = e is StateError ? e.message : 'Téléchargement impossible. Réessayez plus tard.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final size = widget.update.size / (1024 * 1024);
    return AlertDialog(
      backgroundColor: OFColors.surface,
      title: Text('OptiFin ${widget.update.version}', style: OFTypography.title2),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              progress == null
                  ? 'Une nouvelle version est disponible (${size.toStringAsFixed(0)} Mo). '
                        'OptiFin se fermera, s’installera puis se relancera tout seul.'
                  : 'Téléchargement… ${(progress * 100).round()} %',
              style: OFTypography.body.copyWith(color: OFColors.textSecondary),
            ),
            if (progress != null) ...[
              const SizedBox(height: OFSpacing.md),
              LinearProgressIndicator(value: progress),
            ],
            if (_error != null) ...[
              const SizedBox(height: OFSpacing.md),
              Text(_error!, style: OFTypography.callout.copyWith(color: OFColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: progress == null ? () => Navigator.of(context).pop() : null,
          child: const Text('Plus tard'),
        ),
        FilledButton(onPressed: progress == null ? () => unawaited(_install()) : null, child: const Text('Installer')),
      ],
    );
  }
}
