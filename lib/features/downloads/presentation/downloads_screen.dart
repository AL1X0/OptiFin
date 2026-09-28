import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/media/formatters.dart';
import '../../../core/media/media_item.dart';
import '../../../core/providers.dart';
import '../../common/presentation/media_cards.dart';
import '../domain/download.dart';
import 'download_button.dart';
import 'downloads_providers.dart';

/// Onglet « Téléchargements » : films et séries disponibles hors connexion, transferts en
/// cours (progression, pause, reprise), espace occupé ; glisser une ligne pour la supprimer.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(downloadGroupsProvider);
    final gutter = OFSpacing.gutterOf(context);
    final bottom = MediaQuery.paddingOf(context).bottom + 96;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, OFSpacing.lg, gutter, OFSpacing.md),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Expanded(child: Text('Téléchargements', style: OFTypography.title1)),
                    if (groups.value?.isNotEmpty ?? false)
                      OFIconButton(
                        icon: Icons.delete_sweep_outlined,
                        tooltip: 'Tout supprimer',
                        onPressed: () => _confirmDeleteAll(context, ref),
                      ),
                  ],
                ),
              ),
            ),
          ),
          switch (groups) {
            AsyncData(:final value) when value.isEmpty => const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(),
            ),
            AsyncData(:final value) => SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, bottom),
              sliver: SliverList.list(
                children: [
                  _Summary(groups: value),
                  const SizedBox(height: OFSpacing.lg),
                  for (final (i, g) in value.indexed)
                    FadeSlideIn(
                      key: ValueKey(g.id),
                      delay: staggerDelay(i),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: OFSpacing.xl),
                        child: g.isSeries ? _SeriesGroup(group: g) : _DownloadRow(entry: g.first),
                      ),
                    ),
                ],
              ),
            ),
            AsyncError() => const SliverFillRemaining(
              child: StatusMessage(icon: Icons.error_outline_rounded, text: 'Impossible de lire les téléchargements.'),
            ),
            _ => const SliverFillRemaining(child: Center(child: OFLoader())),
          },
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Tout supprimer ?'),
        content: const Text('Tous les films et épisodes téléchargés seront effacés de cet appareil.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: OFColors.danger)),
          ),
        ],
      ),
    );
    if (ok ?? false) await ref.read(downloadsRepositoryProvider).removeAll();
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(OFSpacing.xxl),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.download_for_offline_outlined, size: 56, color: OFColors.textTertiary),
        const SizedBox(height: OFSpacing.lg),
        const Text('Aucun téléchargement', style: OFTypography.title2),
        const SizedBox(height: OFSpacing.sm),
        Text(
          'Appuyez sur le bouton de téléchargement d’un film ou d’un épisode pour le regarder '
          'sans connexion, en avion ou en déplacement.',
          textAlign: TextAlign.center,
          style: OFTypography.callout.copyWith(color: OFColors.textSecondary),
        ),
      ],
    ),
  );
}

/// « 2 films · 1 série · 12,4 Go » et, s'il y en a, les transferts en cours.
class _Summary extends StatelessWidget {
  const _Summary({required this.groups});

  final List<DownloadGroup> groups;

  @override
  Widget build(BuildContext context) {
    final films = groups.where((g) => !g.isSeries).length;
    final series = groups.where((g) => g.isSeries).length;
    final bytes = groups.fold<int>(0, (s, g) => s + g.totalBytes);
    final active = groups.expand((g) => g.entries).where((e) => !e.isComplete).length;
    return Text(
      [
        if (films > 0) '$films film${films > 1 ? 's' : ''}',
        if (series > 0) '$series série${series > 1 ? 's' : ''}',
        formatBytes(bytes),
        if (active > 0) '$active en cours',
      ].join('  ·  '),
      style: OFTypography.callout.copyWith(color: OFColors.textSecondary),
    );
  }
}

/// Série : en-tête (titre, nombre d'épisodes, taille, suppression) puis ses épisodes.
class _SeriesGroup extends ConsumerWidget {
  const _SeriesGroup({required this.group});

  final DownloadGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = group.entries.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.title, style: OFTypography.title2, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    '$n épisode${n > 1 ? 's' : ''}  ·  ${formatBytes(group.totalBytes)}',
                    style: OFTypography.caption.copyWith(color: OFColors.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Supprimer la série',
              icon: const Icon(Icons.delete_outline_rounded, color: OFColors.textSecondary),
              onPressed: () {
                HapticFeedback.mediumImpact();
                unawaited(ref.read(downloadsRepositoryProvider).removeAll(seriesId: group.seriesId));
              },
            ),
          ],
        ),
        const SizedBox(height: OFSpacing.md),
        for (final e in group.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: OFSpacing.md),
            child: _DownloadRow(entry: e),
          ),
      ],
    );
  }
}

/// Ligne d'un film ou d'un épisode : vignette, titre, état et progression, lecture.
/// Glisser vers la gauche supprime ; toucher lit (si disponible) ou ouvre les actions.
class _DownloadRow extends ConsumerWidget {
  const _DownloadRow({required this.entry});

  final DownloadEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = entry.item;
    final episode = item.kind == MediaKind.episode;
    final thumbWidth = episode ? 128.0 : 72.0;
    final thumbHeight = episode ? thumbWidth * 9 / 16 : thumbWidth * 1.5;
    final title = episode ? '${item.episodeLabel ?? ''} · ${item.name}' : item.name;
    final detail = [
      if (entry.isComplete) ...[
        ?MediaFormat.duration(item.runtime),
        if (entry.sizeBytes > 0) formatBytes(entry.sizeBytes),
      ] else ...[
        entry.status.label,
        if (entry.status != DownloadStatus.failed) '${(entry.progress * 100).round()} %',
        if (entry.sizeBytes > 0) formatBytes(entry.sizeBytes),
      ],
    ].join('  ·  ');
    final accent = Theme.of(context).colorScheme.primary;

    void open() {
      HapticFeedback.selectionClick();
      if (entry.isComplete) {
        context.play(item.id);
      } else {
        unawaited(showDownloadActions(context, ref, entry));
      }
    }

    return Dismissible(
      key: ValueKey('dl-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: OFSpacing.xl),
        decoration: const BoxDecoration(color: Color(0x33FF453A), borderRadius: OFRadius.mdAll),
        child: const Icon(Icons.delete_outline_rounded, color: OFColors.danger),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        unawaited(ref.read(downloadsRepositoryProvider).remove(item.id));
      },
      child: Semantics(
        button: true,
        label: '$title, $detail',
        child: InkWell(
          borderRadius: OFRadius.mdAll,
          onTap: open,
          onLongPress: () => showDownloadActions(context, ref, entry),
          child: Row(
            children: [
              _Thumb(entry: entry, width: thumbWidth, height: thumbHeight, episode: episode),
              const SizedBox(width: OFSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: OFTypography.headline, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: OFSpacing.xxs),
                    Text(
                      detail,
                      style: OFTypography.caption.copyWith(
                        color: entry.status == DownloadStatus.failed ? OFColors.danger : OFColors.textSecondary,
                      ),
                    ),
                    if (!entry.isComplete && entry.status != DownloadStatus.failed) ...[
                      const SizedBox(height: OFSpacing.sm),
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: entry.progress),
                        duration: OFMotion.of(context).standard,
                        builder: (context, v, _) => LinearProgressIndicator(
                          value: entry.status == DownloadStatus.queued ? null : v,
                          minHeight: 4,
                          borderRadius: const BorderRadius.all(Radius.circular(2)),
                          backgroundColor: const Color(0x26FFFFFF),
                          color: entry.status == DownloadStatus.paused ? OFColors.textTertiary : accent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: OFSpacing.sm),
              if (entry.isComplete)
                OFIconButton(icon: Icons.play_arrow_rounded, tooltip: 'Lire', onPressed: () => context.play(item.id))
              else
                DownloadButton(itemId: item.id, size: 40),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vignette : image enregistrée avec le téléchargement (disponible hors connexion),
/// sinon image du serveur.
class _Thumb extends ConsumerWidget {
  const _Thumb({required this.entry, required this.width, required this.height, required this.episode});

  final DownloadEntry entry;
  final double width;
  final double height;
  final bool episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final path = entry.posterPath;
    final file = path == null ? null : File(path);
    final Widget image;
    if (file != null && file.existsSync()) {
      image = Image.file(file, fit: BoxFit.cover, cacheWidth: (width * dpr).ceil(), gaplessPlayback: true);
    } else {
      final item = entry.item;
      final ref0 = episode ? (item.primary ?? item.landscape) : item.poster;
      image = OFImage(
        url: ref.watch(imageUrlBuilderProvider).maybe(ref0, logicalWidth: width, devicePixelRatio: dpr),
        blurHash: ref0?.blurHash,
        decodeWidth: (width * dpr).ceil(),
        fallback: const ColoredBox(
          color: OFColors.surfaceRaised,
          child: Center(child: Icon(Icons.movie_outlined, color: OFColors.textTertiary)),
        ),
      );
    }
    return ClipRRect(
      borderRadius: OFRadius.smAll,
      child: SizedBox(width: width, height: height, child: image),
    );
  }
}
