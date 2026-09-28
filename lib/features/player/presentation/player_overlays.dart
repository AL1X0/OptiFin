import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/media/formatters.dart';
import '../../../core/media/media_item.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../../common/presentation/media_cards.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/presentation/settings_providers.dart';
import '../domain/playback_extras.dart';
import 'player_controller.dart';

/// Bouton « Passer l'intro » (et récap, aperçu, générique) : visible même contrôles masqués.
class SkipSegmentButton extends StatelessWidget {
  const SkipSegmentButton({super.key, required this.segment, required this.onSkip});

  final MediaSegment segment;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => OFButton.secondary(
    label: segment.type.skipLabel,
    icon: Icons.skip_next_rounded,
    onPressed: () {
      HapticFeedback.selectionClick();
      onSkip();
    },
  );
}

/// Carte « Épisode suivant » pendant le générique, avec compte à rebours.
class UpNextCard extends ConsumerStatefulWidget {
  const UpNextCard({
    super.key,
    required this.next,
    required this.autoPlay,
    required this.onPlay,
    required this.onDismiss,
    this.countdown = const Duration(seconds: 10),
  });

  final MediaItem next;
  final bool autoPlay;
  final Duration countdown;
  final VoidCallback onPlay;
  final VoidCallback onDismiss;

  @override
  ConsumerState<UpNextCard> createState() => _UpNextCardState();
}

class _UpNextCardState extends ConsumerState<UpNextCard> with SingleTickerProviderStateMixin {
  late final _progress = AnimationController(vsync: this, duration: widget.countdown);

  @override
  void initState() {
    super.initState();
    if (widget.autoPlay) {
      _progress.forward().whenComplete(() {
        if (mounted && _progress.isCompleted) widget.onPlay();
      });
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = ref.watch(imageUrlBuilderProvider);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final next = widget.next;
    final image = next.landscape ?? next.backdrop;
    const width = 300.0;
    return Semantics(
      container: true,
      label: 'Épisode suivant : ${next.name}',
      child: ClipRRect(
        borderRadius: OFRadius.lgAll,
        child: GlassSurface(
          borderRadius: OFRadius.lgAll,
          child: ColoredBox(
            color: const Color(0xB3000000),
            child: SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        OFImage(
                          url: images.maybe(image, logicalWidth: width, devicePixelRatio: dpr),
                          blurHash: image?.blurHash,
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: AnimatedBuilder(
                            animation: _progress,
                            builder: (context, _) => LinearProgressIndicator(
                              value: widget.autoPlay ? _progress.value : 0,
                              minHeight: 3,
                              backgroundColor: const Color(0x33FFFFFF),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(OFSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ÉPISODE SUIVANT',
                          style: OFTypography.caption.copyWith(color: OFColors.textTertiary, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: OFSpacing.xs),
                        Text(
                          [?next.episodeLabel, next.name].join(' · '),
                          style: OFTypography.callout,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: OFSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: AnimatedBuilder(
                                animation: _progress,
                                builder: (context, _) {
                                  final left = widget.countdown * (1 - _progress.value);
                                  return OFButton(
                                    label: widget.autoPlay && _progress.isAnimating
                                        ? 'Lecture dans ${left.inSeconds + 1} s'
                                        : 'Lire',
                                    icon: Icons.play_arrow_rounded,
                                    expand: true,
                                    onPressed: widget.onPlay,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: OFSpacing.sm),
                            OFIconButton(
                              icon: Icons.close_rounded,
                              tooltip: 'Continuer le générique',
                              onPressed: widget.onDismiss,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vignette de prévisualisation au-dessus de la barre de progression pendant le glissé.
///
/// Les vignettes trickplay sont des planches JPEG (ex. 10 × 10 images) : on affiche
/// la bonne case par recadrage, la planche restant en cache pour les cases voisines.
class TrickplayPreview extends ConsumerWidget {
  const TrickplayPreview({
    super.key,
    required this.manifest,
    required this.itemId,
    required this.mediaSourceId,
    required this.position,
    this.width = 176,
  });

  final TrickplayManifest manifest;
  final String itemId;
  final String? mediaSourceId;
  final Duration position;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tile = manifest.tileAt(position);
    final height = width * manifest.height / manifest.width;
    final sheetWidth = width * manifest.tileWidth;
    final sheetHeight = height * manifest.tileHeight;
    final url = ref
        .watch(imageUrlBuilderProvider)
        .trickplaySheet(itemId, width: manifest.width, sheet: tile.sheet, mediaSourceId: mediaSourceId);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: OFColors.surfaceRaised,
            borderRadius: OFRadius.mdAll,
            border: Border.all(color: OFColors.textPrimary.withValues(alpha: 0.8), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: sheetWidth,
            maxWidth: sheetWidth,
            minHeight: sheetHeight,
            maxHeight: sheetHeight,
            child: Transform.translate(
              offset: Offset(-tile.column * width, -tile.row * height),
              child: Image(
                image: OFImageSource.resolve(url.toString(), headers: ref.watch(playbackHeadersProvider)),
                width: sheetWidth,
                height: sheetHeight,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        const SizedBox(height: OFSpacing.xs),
        _TimeBubble(position),
      ],
    );
  }
}

class _TimeBubble extends StatelessWidget {
  const _TimeBubble(this.position);

  final Duration position;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(color: Color(0xCC000000), borderRadius: OFRadius.smAll),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: OFSpacing.sm, vertical: OFSpacing.xxs),
      child: Text(
        MediaFormat.clock(position),
        style: OFTypography.caption.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    ),
  );
}

/// Aperçu sans trickplay : l'heure et le chapitre visé.
class ScrubLabel extends StatelessWidget {
  const ScrubLabel({super.key, required this.position, this.chapter});

  final Duration position;
  final Chapter? chapter;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (chapter != null)
        Padding(
          padding: const EdgeInsets.only(bottom: OFSpacing.xs),
          child: Text(chapter!.name, style: OFTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      _TimeBubble(position),
    ],
  );
}

/// Indicateur de luminosité / volume pendant un glissé vertical.
class LevelIndicator extends StatelessWidget {
  const LevelIndicator({super.key, required this.icon, required this.value});

  final IconData icon;
  final double value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: OFSpacing.lg, vertical: OFSpacing.md),
    decoration: const BoxDecoration(
      color: Color(0x99000000),
      borderRadius: BorderRadius.all(Radius.circular(OFRadius.pill)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: OFColors.textPrimary),
        const SizedBox(width: OFSpacing.md),
        SizedBox(
          width: 120,
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(2)),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              minHeight: 4,
              backgroundColor: const Color(0x33FFFFFF),
              color: OFColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Liste des chapitres avec vignettes ; le chapitre en cours est mis en avant.
class ChaptersSheet extends ConsumerWidget {
  const ChaptersSheet({
    super.key,
    required this.itemId,
    required this.chapters,
    required this.current,
    required this.onSelect,
  });

  final String itemId;
  final List<Chapter> chapters;
  final Chapter? current;
  final ValueChanged<Chapter> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(imageUrlBuilderProvider);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final accent = Theme.of(context).colorScheme.primary;
    const thumbWidth = 128.0;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(OFSpacing.lg, 0, OFSpacing.lg, OFSpacing.xl),
        itemCount: chapters.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return const Padding(
              padding: EdgeInsets.all(OFSpacing.sm),
              child: Text('Chapitres', style: OFTypography.title2),
            );
          }
          final c = chapters[i - 1];
          final selected = identical(c, current);
          return InkWell(
            borderRadius: OFRadius.mdAll,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(c);
            },
            child: Padding(
              padding: const EdgeInsets.all(OFSpacing.sm),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: OFRadius.smAll,
                    child: SizedBox(
                      width: thumbWidth,
                      height: thumbWidth * 9 / 16,
                      child: c.imageTag == null
                          ? const ColoredBox(
                              color: OFColors.surfaceRaised,
                              child: Icon(Icons.movie_outlined, color: OFColors.textTertiary),
                            )
                          : OFImage(
                              url: images.chapterImage(
                                itemId,
                                c.index,
                                tag: c.imageTag,
                                logicalWidth: thumbWidth,
                                devicePixelRatio: dpr,
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
                          c.name,
                          style: OFTypography.callout.copyWith(color: selected ? accent : OFColors.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          MediaFormat.clock(c.start),
                          style: OFTypography.caption.copyWith(color: OFColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  if (selected) Icon(Icons.play_arrow_rounded, color: accent),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Recherche de sous-titres via les fournisseurs du serveur (ex. plugin OpenSubtitles).
class SubtitleSearchSheet extends ConsumerStatefulWidget {
  const SubtitleSearchSheet({super.key, required this.controller});

  final PlayerController controller;

  @override
  ConsumerState<SubtitleSearchSheet> createState() => _SubtitleSearchSheetState();
}

class _SubtitleSearchSheetState extends ConsumerState<SubtitleSearchSheet> {
  late String _language = ref.read(settingsProvider).subtitleLanguage ?? 'fre';
  Future<List<RemoteSubtitle>>? _results;
  String? _downloading;

  @override
  void initState() {
    super.initState();
    _search();
  }

  void _search() => setState(() => _results = widget.controller.searchSubtitles(_language));

  Future<void> _download(RemoteSubtitle s) async {
    setState(() => _downloading = s.id);
    try {
      await widget.controller.downloadSubtitle(s);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e is ApiFailure ? e.userMessage : 'Téléchargement impossible.')));
    } finally {
      if (mounted) setState(() => _downloading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(OFSpacing.lg, 0, OFSpacing.lg, OFSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(OFSpacing.sm),
              child: Text('Rechercher des sous-titres', style: OFTypography.title2),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final e in preferredLanguages.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: OFSpacing.sm),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: e.key == _language,
                        showCheckmark: false,
                        onSelected: (_) {
                          _language = e.key;
                          _search();
                        },
                        labelStyle: OFTypography.caption.copyWith(
                          color: e.key == _language ? OFColors.background : OFColors.textPrimary,
                        ),
                        selectedColor: accent,
                        backgroundColor: OFColors.surfaceRaised,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                      ),
                    ),
                ],
              ),
            ),
            Flexible(
              child: FutureBuilder<List<RemoteSubtitle>>(
                future: _results,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(OFSpacing.xxl),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                    );
                  }
                  if (snap.hasError) {
                    final e = snap.error;
                    return StatusMessage(
                      text: e is ApiFailure ? e.userMessage : 'Recherche impossible.',
                      onRetry: _search,
                    );
                  }
                  final list = snap.data ?? const [];
                  if (list.isEmpty) {
                    return const StatusMessage(
                      text: 'Aucun sous-titre trouvé. Un fournisseur (ex. OpenSubtitles) doit être installé sur le serveur.',
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final s = list[i];
                      return ListTile(
                        shape: const RoundedRectangleBorder(borderRadius: OFRadius.mdAll),
                        title: Text(s.name, style: OFTypography.callout, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(s.detail, style: OFTypography.caption.copyWith(color: OFColors.textTertiary)),
                        trailing: _downloading == s.id
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.download_rounded, color: OFColors.textSecondary),
                        onTap: _downloading == null ? () => unawaited(_download(s)) : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
