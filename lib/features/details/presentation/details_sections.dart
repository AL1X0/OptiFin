import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation.dart';
import '../../../core/design_system/design_system.dart';
import '../../downloads/presentation/download_button.dart';
import '../../../core/media/formatters.dart';
import '../../../core/media/media_item.dart';
import '../../../core/media/quality_badges.dart';
import '../../../core/providers.dart';
import '../../common/presentation/media_cards.dart';
import '../../home/domain/home_data.dart';
import 'details_providers.dart';
import 'item_details_screen.dart';

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final gutter = OFSpacing.gutterOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, OFSpacing.xxl, gutter, OFSpacing.md),
      child: Semantics(header: true, child: Text(title, style: OFTypography.title2)),
    );
  }
}

/// Saisons (puces) + épisodes de la saison sélectionnée.
class SeasonsSection extends ConsumerStatefulWidget {
  const SeasonsSection({super.key, required this.series, this.initialSeasonId});

  final MediaItem series;
  final String? initialSeasonId;

  @override
  ConsumerState<SeasonsSection> createState() => _SeasonsSectionState();
}

class _SeasonsSectionState extends ConsumerState<SeasonsSection> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final seasons = ref.watch(seasonsProvider(widget.series.id)).value;
    if (seasons == null) {
      return const Padding(
        padding: EdgeInsets.all(OFSpacing.xxl),
        child: Center(child: OFLoader()),
      );
    }
    if (seasons.isEmpty) return const SizedBox.shrink();

    // Saison par défaut : demandée, sinon celle de l'épisode « à suivre », sinon la première non vue.
    final nextUp = ref.watch(nextUpForSeriesProvider(widget.series.id)).value;
    final selectedId =
        _selected ??
        widget.initialSeasonId ??
        nextUp?.seasonId ??
        seasons.firstWhere((s) => !s.user.played, orElse: () => seasons.first).id;
    final gutter = OFSpacing.gutterOf(context);
    final accent = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Épisodes'),
        if (seasons.length > 1)
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: gutter),
              itemCount: seasons.length,
              separatorBuilder: (_, _) => const SizedBox(width: OFSpacing.sm),
              itemBuilder: (context, i) {
                final s = seasons[i];
                final selected = s.id == selectedId;
                return ChoiceChip(
                  label: Text(s.name),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _selected = s.id);
                  },
                  labelStyle: OFTypography.callout.copyWith(
                    color: selected ? OFColors.background : OFColors.textPrimary,
                  ),
                  selectedColor: accent,
                  backgroundColor: OFColors.surfaceRaised,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                );
              },
            ),
          ),
        const SizedBox(height: OFSpacing.lg),
        _EpisodeList(seriesId: widget.series.id, seasonId: selectedId, highlightId: nextUp?.id),
      ],
    );
  }
}

class _EpisodeList extends ConsumerWidget {
  const _EpisodeList({required this.seriesId, required this.seasonId, this.highlightId});

  final String seriesId;
  final String seasonId;
  final String? highlightId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodes = ref.watch(episodesProvider((seriesId, seasonId)));
    final gutter = OFSpacing.gutterOf(context);
    return switch (episodes) {
      AsyncData(:final value) => AnimatedSwitcher(
        duration: OFMotion.of(context).standard,
        child: Column(
          key: ValueKey(seasonId),
          children: [
            // Saison entière hors connexion (épisodes déjà téléchargés ignorés). Pas sur TV.
            if (!OFDevice.tv)
              Padding(
                padding: EdgeInsets.fromLTRB(gutter - OFSpacing.sm, 0, gutter, OFSpacing.sm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => startDownload(context, ref, [for (final e in value) e.id]),
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: Text(
                      'Télécharger la saison (${value.length} épisode${value.length > 1 ? 's' : ''})',
                      style: OFTypography.callout,
                    ),
                  ),
                ),
              ),
            for (final e in value)
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, OFSpacing.lg),
                child: EpisodeTile(episode: e, highlighted: e.id == highlightId),
              ),
          ],
        ),
      ),
      AsyncError() => StatusMessage(
        text: 'Impossible de charger les épisodes.',
        onRetry: () => ref.invalidate(episodesProvider((seriesId, seasonId))),
      ),
      _ => const Padding(
        padding: EdgeInsets.all(OFSpacing.xl),
        child: Center(child: OFLoader()),
      ),
    };
  }
}

/// Épisode : vignette + titre + durée + synopsis court + progression.
class EpisodeTile extends ConsumerWidget {
  const EpisodeTile({super.key, required this.episode, this.highlighted = false});

  final MediaItem episode;
  final bool highlighted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final thumbWidth = wide ? 240.0 : 150.0;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final images = ref.watch(imageUrlBuilderProvider);
    final user = ref.watch(userStateProvider(episode.id)) ?? episode.user;
    final index = episode.indexNumber;
    final title = index == null ? episode.name : '$index. ${episode.name}';
    final duration = MediaFormat.duration(episode.runtime);
    final heroTag = 'ep:${episode.id}';

    return Semantics(
      button: true,
      label: [title, ?duration, if (user.played) 'vu'].join(', '),
      excludeSemantics: true,
      onTap: () => context.openItem(episode, heroTag: heroTag),
      child: InkWell(
        borderRadius: OFRadius.mdAll,
        onTap: () => context.openItem(episode, heroTag: heroTag),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: OFRadius.mdAll,
              child: SizedBox(
                width: thumbWidth,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: heroTag,
                        child: OFImage(
                          url: images.maybe(episode.landscape, logicalWidth: thumbWidth, devicePixelRatio: dpr),
                          blurHash: episode.landscape?.blurHash,
                          decodeWidth: (thumbWidth * dpr).ceil(),
                          fallback: const ColoredBox(
                            color: OFColors.surfaceRaised,
                            child: Center(child: Icon(Icons.tv_rounded, color: OFColors.textTertiary)),
                          ),
                        ),
                      ),
                      if (user.progress != null)
                        Positioned(
                          left: OFSpacing.sm,
                          right: OFSpacing.sm,
                          bottom: OFSpacing.sm,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.all(Radius.circular(2)),
                            child: LinearProgressIndicator(value: user.progress, minHeight: 3),
                          ),
                        ),
                      if (user.played)
                        const Positioned(
                          top: OFSpacing.xs,
                          right: OFSpacing.xs,
                          child: Icon(Icons.check_circle_rounded, size: 20, color: OFColors.textPrimary),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: OFSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: OFTypography.headline.copyWith(
                      color: highlighted ? Theme.of(context).colorScheme.primary : OFColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (duration != null)
                    Text(duration, style: OFTypography.caption.copyWith(color: OFColors.textTertiary)),
                  if (episode.overview != null) ...[
                    const SizedBox(height: OFSpacing.xs),
                    Text(
                      episode.overview!,
                      style: OFTypography.callout.copyWith(color: OFColors.textSecondary),
                      maxLines: wide ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: OFSpacing.sm),
            DownloadButton(itemId: episode.id, size: 38),
          ],
        ),
      ),
    );
  }
}

/// Éléments d'une collection ou d'une playlist.
class ChildrenSection extends ConsumerWidget {
  const ChildrenSection({super.key, required this.parent});

  final MediaItem parent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenProvider(parent.id)).value;
    if (children == null || children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: OFSpacing.xxl),
      child: MediaItemsRow(
        title: parent.kind == MediaKind.playlist ? 'Contenu' : 'Dans cette collection',
        items: children,
        style: childStyle(parent),
        heroScope: 'children',
      ),
    );
  }
}

/// Distribution : photos rondes + rôle.
class CastSection extends ConsumerWidget {
  const CastSection({super.key, required this.people});

  final List<PersonCredit> people;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cast = people.where((p) => p.kind == PersonKind.actor || p.kind == PersonKind.guestStar).take(30).toList();
    if (cast.isEmpty) return const SizedBox.shrink();
    final gutter = OFSpacing.gutterOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final images = ref.watch(imageUrlBuilderProvider);
    const size = 84.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Distribution'),
        SizedBox(
          height: size + 52,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: gutter),
            itemExtent: size + OFSpacing.lg,
            itemCount: cast.length,
            itemBuilder: (context, i) {
              final p = cast[i];
              return Semantics(
                button: true,
                label: [p.name, ?p.role].join(', '),
                excludeSemantics: true,
                onTap: () => context.openPerson(p.id),
                child: GestureDetector(
                  onTap: () => context.openPerson(p.id),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AvatarChip(
                        name: p.name,
                        size: size,
                        imageUrl: images.maybe(p.image, logicalWidth: size, devicePixelRatio: dpr),
                      ),
                      const SizedBox(height: OFSpacing.sm),
                      SizedBox(
                        width: size,
                        child: Text(p.name, style: OFTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (p.role != null)
                        SizedBox(
                          width: size,
                          child: Text(
                            p.role!,
                            style: OFTypography.caption.copyWith(color: OFColors.textTertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class SimilarSection extends ConsumerWidget {
  const SimilarSection({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final similar = ref.watch(similarProvider(itemId)).value;
    if (similar == null || similar.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: OFSpacing.xxl),
      child: MediaItemsRow(title: 'Titres similaires', items: similar, style: CardStyle.poster, heroScope: 'similar'),
    );
  }
}

/// Informations techniques : vidéo + pistes audio.
class TechnicalSection extends StatelessWidget {
  const TechnicalSection({super.key, required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final gutter = OFSpacing.gutterOf(context);
    final video = item.streams.where((s) => s.isVideo).firstOrNull;
    final audios = item.streams.where((s) => !s.isVideo).toList();

    String videoLine(StreamSummary v) => [
      v.codec.toUpperCase(),
      ?resolutionLabel(v.width, v.height),
      if (v.width != null && v.height != null) '${v.width}×${v.height}',
      if (v.bitDepth != null) '${v.bitDepth} bits',
      switch (v.videoRange) {
        VideoRange.dolbyVision => 'Dolby Vision',
        VideoRange.hdr10Plus => 'HDR10+',
        VideoRange.hdr10 => 'HDR10',
        VideoRange.hlg => 'HLG',
        VideoRange.sdr => 'SDR',
      },
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Informations techniques'),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (video != null) _TechRow(label: 'Vidéo', value: videoLine(video)),
              for (final (i, a) in audios.take(6).indexed)
                _TechRow(
                  label: i == 0 ? 'Audio' : '',
                  value: a.title ?? [a.codec.toUpperCase(), ?a.language].join(' · '),
                ),
              if (audios.length > 6) _TechRow(label: '', value: '+ ${audios.length - 6} autres pistes'),
            ],
          ),
        ),
      ],
    );
  }
}

class _TechRow extends StatelessWidget {
  const _TechRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: OFSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: OFTypography.callout.copyWith(color: OFColors.textTertiary)),
        ),
        Expanded(
          child: Text(value, style: OFTypography.callout.copyWith(color: OFColors.textSecondary)),
        ),
      ],
    ),
  );
}
