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
import '../../../core/l10n/l.dart';

/// Onglet « Téléchargements » : films et séries disponibles hors connexion, transferts en
/// cours (progression, pause, reprise), espace occupé ; glisser une ligne pour la supprimer.
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  final Set<String> _hiddenItems = {};
  final Set<String> _hiddenSeries = {};

  void _deleteEntry(DownloadEntry entry) {
    if (_hiddenItems.contains(entry.itemId)) return;
    final repo = ref.read(downloadsRepositoryProvider);
    _scheduleUndoableDelete(
      hide: () => _hiddenItems.add(entry.itemId),
      show: () => _hiddenItems.remove(entry.itemId),
      commit: () => repo.remove(entry.itemId),
    );
  }

  void _deleteSeries(DownloadGroup group) {
    final seriesId = group.seriesId;
    if (seriesId == null) {
      final ids = [for (final e in group.entries) e.itemId];
      final repo = ref.read(downloadsRepositoryProvider);
      _scheduleUndoableDelete(
        hide: () => _hiddenItems.addAll(ids),
        show: () => _hiddenItems.removeAll(ids),
        commit: () async {
          for (final id in ids) {
            await repo.remove(id);
          }
        },
      );
      return;
    }
    if (_hiddenSeries.contains(seriesId)) return;
    final repo = ref.read(downloadsRepositoryProvider);
    _scheduleUndoableDelete(
      hide: () => _hiddenSeries.add(seriesId),
      show: () => _hiddenSeries.remove(seriesId),
      commit: () => repo.removeAll(seriesId: seriesId),
    );
  }

  void _scheduleUndoableDelete({
    required VoidCallback hide,
    required VoidCallback show,
    required Future<void> Function() commit,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    setState(hide);
    // Fermer un éventuel SnackBar précédent : sa fermeture déclenche sa suppression réelle.
    messenger.hideCurrentSnackBar();
    var undone = false;
    final controller = messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Text(L.t('Supprimé')),
        action: SnackBarAction(
          label: L.t('Annuler'),
          onPressed: () {
            undone = true;
            if (mounted) setState(show);
          },
        ),
      ),
    );
    unawaited(
      controller.closed.then((reason) async {
        if (undone || reason == SnackBarClosedReason.action) {
          if (mounted) setState(show);
          return;
        }
        try {
          await commit();
        } finally {
          if (mounted) setState(show);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(downloadGroupsProvider);
    final visibleGroups = switch (groups) {
      AsyncData(:final value) => [
        for (final g in value)
          if (g.seriesId == null || !_hiddenSeries.contains(g.seriesId))
            if (g.entries.where((e) => !_hiddenItems.contains(e.itemId)).toList() case final entries
                when entries.isNotEmpty)
              DownloadGroup(id: g.id, title: g.title, seriesId: g.seriesId, entries: entries),
      ],
      _ => null,
    };
    final gutter = OFSpacing.gutterOf(context);
    final bottom = MediaQuery.paddingOf(context).bottom + 96;

    return ScrollToTopListener(
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            OFLargeTitleSliver(
              title: L.t('Téléchargements'),
              actions: [
                if (visibleGroups?.isNotEmpty ?? false)
                  OFIconButton(
                    icon: Icons.delete_sweep_outlined,
                    tooltip: L.t('Tout supprimer'),
                    onPressed: () => _confirmDeleteAll(context, ref),
                  ),
              ],
            ),
            const SliverToBoxAdapter(child: SizedBox(height: OFSpacing.sm)),
            switch (groups) {
              AsyncData() when visibleGroups!.isEmpty => const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(),
              ),
              AsyncData() => SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, bottom),
                sliver: SliverList.list(
                  children: [
                    _Summary(groups: visibleGroups!),
                    const SizedBox(height: OFSpacing.lg),
                    for (final (i, g) in visibleGroups.indexed)
                      FadeSlideIn(
                        key: ValueKey(g.id),
                        delay: staggerDelay(i),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: OFSpacing.xl),
                          child: g.isSeries
                              ? _SeriesGroup(
                                  group: g,
                                  onDeleteSeries: () => _deleteSeries(g),
                                  onDeleteEntry: _deleteEntry,
                                )
                              : _DownloadRow(entry: g.first, onDelete: () => _deleteEntry(g.first)),
                        ),
                      ),
                  ],
                ),
              ),
              AsyncError() => SliverFillRemaining(
                child: StatusMessage(
                  icon: Icons.error_outline_rounded,
                  text: L.t('Impossible de lire les téléchargements.'),
                ),
              ),
              _ => const SliverFillRemaining(child: Center(child: OFLoader())),
            },
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(L.t('Tout supprimer ?')),
        content: Text(L.t('Tous les films et épisodes téléchargés seront effacés de cet appareil.')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(L.t('Annuler'))),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(L.t('Supprimer'), style: const TextStyle(color: OFColors.danger)),
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
        Text(L.t('Aucun téléchargement'), style: OFTypography.title2),
        const SizedBox(height: OFSpacing.sm),
        Text(
          L.t('Appuyez sur le bouton de téléchargement d’un film ou d’un épisode pour le regarder ') +
              L.t('sans connexion, en avion ou en déplacement.'),
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
        if (films > 0) L.count(films, '{0} film', '{0} films'),
        if (series > 0) L.count(series, '{0} série', '{0} séries'),
        formatBytes(bytes),
        if (active > 0) L.f('{0} en cours', [active]),
      ].join('  ·  '),
      style: OFTypography.callout.copyWith(color: OFColors.textSecondary),
    );
  }
}

/// Série : en-tête (titre, nombre d'épisodes, taille, suppression) puis ses épisodes.
class _SeriesGroup extends StatelessWidget {
  const _SeriesGroup({required this.group, required this.onDeleteSeries, required this.onDeleteEntry});

  final DownloadGroup group;
  final VoidCallback onDeleteSeries;
  final void Function(DownloadEntry) onDeleteEntry;

  @override
  Widget build(BuildContext context) {
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
                    L.f(n > 1 ? '{0} épisodes  ·  {1}' : '{0} épisode  ·  {1}', [n, formatBytes(group.totalBytes)]),
                    style: OFTypography.caption.copyWith(color: OFColors.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: L.t('Supprimer la série'),
              icon: const Icon(Icons.delete_outline_rounded, color: OFColors.textSecondary),
              onPressed: () {
                HapticFeedback.mediumImpact();
                onDeleteSeries();
              },
            ),
          ],
        ),
        const SizedBox(height: OFSpacing.md),
        for (final e in group.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: OFSpacing.md),
            child: _DownloadRow(entry: e, onDelete: () => onDeleteEntry(e)),
          ),
      ],
    );
  }
}

/// Ligne d'un film ou d'un épisode : vignette, titre, état et progression, lecture.
/// Glisser vers la gauche supprime ; toucher lit (si disponible) ou ouvre les actions.
class _DownloadRow extends ConsumerWidget {
  const _DownloadRow({required this.entry, required this.onDelete});

  final DownloadEntry entry;
  final VoidCallback onDelete;

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
        onDelete();
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
                OFIconButton(icon: Icons.play_arrow_rounded, tooltip: L.t('Lire'), onPressed: () => context.play(item.id))
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
class _Thumb extends ConsumerStatefulWidget {
  const _Thumb({required this.entry, required this.width, required this.height, required this.episode});

  final DownloadEntry entry;
  final double width;
  final double height;
  final bool episode;

  @override
  ConsumerState<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends ConsumerState<_Thumb> {
  Future<bool>? _existsFuture;

  @override
  void initState() {
    super.initState();
    _refreshExists();
  }

  @override
  void didUpdateWidget(covariant _Thumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.posterPath != widget.entry.posterPath) _refreshExists();
  }

  void _refreshExists() {
    final path = widget.entry.posterPath;
    _existsFuture = path == null ? null : File(path).exists();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final path = widget.entry.posterPath;
    const placeholder = ColoredBox(
      color: OFColors.surfaceRaised,
      child: Center(child: Icon(Icons.movie_outlined, color: OFColors.textTertiary)),
    );

    Widget buildServerImage() {
      final item = widget.entry.item;
      final ref0 = widget.episode ? (item.primary ?? item.landscape) : item.poster;
      return OFImage(
        url: ref.watch(imageUrlBuilderProvider).maybe(ref0, logicalWidth: widget.width, devicePixelRatio: dpr),
        blurHash: ref0?.blurHash,
        decodeWidth: (widget.width * dpr).ceil(),
        fallback: placeholder,
      );
    }

    final Widget image = path == null
        ? buildServerImage()
        : FutureBuilder<bool>(
            future: _existsFuture,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return placeholder;
              if (snap.data ?? false) {
                return Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  cacheWidth: (widget.width * dpr).ceil(),
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => buildServerImage(),
                );
              }
              return buildServerImage();
            },
          );

    return ClipRRect(
      borderRadius: OFRadius.smAll,
      child: SizedBox(width: widget.width, height: widget.height, child: image),
    );
  }
}
