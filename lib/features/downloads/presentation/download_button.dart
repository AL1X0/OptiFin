import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../../settings/presentation/settings_providers.dart';
import '../domain/download.dart';
import 'downloads_providers.dart';

/// Lance le téléchargement de [itemIds] (message d'erreur lisible en cas d'échec).
Future<void> startDownload(BuildContext context, WidgetRef ref, List<String> itemIds) async {
  unawaited(HapticFeedback.lightImpact());
  final repo = ref.read(downloadsRepositoryProvider);
  final wifiOnly = ref.read(settingsProvider).downloadWifiOnly;
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (itemIds.length == 1) {
      await repo.add(itemIds.single, wifiOnly: wifiOnly);
    } else {
      await repo.addAll(itemIds, wifiOnly: wifiOnly);
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          itemIds.length == 1
              ? 'Téléchargement lancé${wifiOnly ? ' (Wi-Fi uniquement)' : ''}.'
              : '${itemIds.length} épisodes ajoutés aux téléchargements.',
        ),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Téléchargement impossible : $e')));
  }
}

/// Bouton rond « Télécharger » d'une fiche (film, épisode) : anneau de progression
/// pendant le transfert, coche une fois disponible hors connexion ; un toucher sur un
/// téléchargement existant propose pause, reprise ou suppression.
class DownloadButton extends ConsumerWidget {
  const DownloadButton({super.key, required this.itemId, this.size = 44});

  final String itemId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Téléviseur : pas de téléchargements hors connexion.
    final entry = ref.watch(downloadForItemProvider(itemId)).value;
    final accent = Theme.of(context).colorScheme.primary;
    final status = entry?.status;
    final (icon, label) = switch (status) {
      null => (Icons.download_rounded, 'Télécharger'),
      DownloadStatus.queued => (Icons.schedule_rounded, 'Téléchargement en attente'),
      DownloadStatus.running => (Icons.stop_rounded, 'Téléchargement en cours'),
      DownloadStatus.paused => (Icons.pause_rounded, 'Téléchargement en pause'),
      DownloadStatus.complete => (Icons.download_done_rounded, 'Téléchargé'),
      DownloadStatus.failed => (Icons.error_outline_rounded, 'Échec du téléchargement'),
    };

    return Semantics(
      button: true,
      label: entry == null ? label : '$label, ${(entry.progress * 100).round()} %',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          if (entry == null) {
            unawaited(startDownload(context, ref, [itemId]));
          } else {
            unawaited(showDownloadActions(context, ref, entry));
          }
        },
        child: GlassPress(
          scale: 1.12,
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                GlassSurface(
                  borderRadius: BorderRadius.all(Radius.circular(size / 2)),
                  child: SizedBox.square(dimension: size),
                ),
                if (status == DownloadStatus.running ||
                    status == DownloadStatus.paused ||
                    status == DownloadStatus.queued)
                  SizedBox.square(
                    dimension: size - 6,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: entry!.progress),
                      duration: OFMotion.of(context).standard,
                      builder: (context, v, _) => CircularProgressIndicator(
                        value: status == DownloadStatus.queued ? null : v,
                        strokeWidth: 2.5,
                        color: accent,
                        backgroundColor: const Color(0x26FFFFFF),
                      ),
                    ),
                  ),
                AnimatedStateIcon(
                  icon: icon,
                  size: status == DownloadStatus.running ? 16 : 20,
                  color: switch (status) {
                    DownloadStatus.complete => accent,
                    DownloadStatus.failed => OFColors.danger,
                    _ => OFColors.textPrimary,
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Feuille d'actions d'un téléchargement : pause / reprise / nouvel essai / suppression.
Future<void> showDownloadActions(BuildContext context, WidgetRef ref, DownloadEntry entry) {
  final repo = ref.read(downloadsRepositoryProvider);
  final item = entry.item;
  final title = item.seriesName != null && item.indexNumber != null
      ? '${item.seriesName} · S${item.parentIndexNumber ?? 0} É${item.indexNumber}'
      : item.name;
  return showOFSheet<void>(
    context,
    builder: (sheet) {
      Widget action(IconData icon, String label, Future<void> Function() run, {bool danger = false}) => ListTile(
        leading: Icon(icon, color: danger ? OFColors.danger : OFColors.textPrimary),
        title: Text(label, style: OFTypography.body.copyWith(color: danger ? OFColors.danger : null)),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(sheet).pop();
          unawaited(run());
        },
      );
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(OFSpacing.sm, 0, OFSpacing.sm, OFSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(OFSpacing.lg, OFSpacing.sm, OFSpacing.lg, OFSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: OFTypography.headline, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: OFSpacing.xxs),
                    Text(
                      [
                        entry.status.label,
                        if (!entry.isComplete && entry.status != DownloadStatus.failed)
                          '${(entry.progress * 100).round()} %',
                        if (entry.sizeBytes > 0) formatBytes(entry.sizeBytes),
                      ].join(' · '),
                      style: OFTypography.caption.copyWith(color: OFColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (entry.status.active) action(Icons.pause_rounded, 'Mettre en pause', () => repo.pause(entry.itemId)),
              if (entry.status == DownloadStatus.paused)
                action(Icons.play_arrow_rounded, 'Reprendre', () => repo.resume(entry.itemId)),
              if (entry.status == DownloadStatus.failed)
                action(Icons.refresh_rounded, 'Réessayer', () => repo.resume(entry.itemId)),
              action(
                entry.isComplete ? Icons.delete_outline_rounded : Icons.close_rounded,
                entry.isComplete ? 'Supprimer le téléchargement' : 'Annuler le téléchargement',
                () => repo.remove(entry.itemId),
                danger: true,
              ),
            ],
          ),
        ),
      );
    },
  );
}
