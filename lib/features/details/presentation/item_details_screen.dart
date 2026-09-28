import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/navigation.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/media/formatters.dart';
import '../../../core/media/media_item.dart';
import '../../../core/media/quality_badges.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../../common/presentation/media_cards.dart';
import '../../home/domain/home_data.dart';
import '../../player/presentation/player_controller.dart';
import 'details_providers.dart';
import 'details_sections.dart';

/// Fiche film / série / épisode / collection.
class ItemDetailsScreen extends ConsumerWidget {
  const ItemDetailsScreen({super.key, required this.itemId, this.heroTag, this.initialSeasonId});

  final String itemId;
  final String? heroTag;
  final String? initialSeasonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(itemProvider(itemId));
    // Chargement → fiche : fondu enchaîné (le Hero de la carte se pose pendant ce temps).
    return FadeThroughSwitcher(
      child: switch (item) {
        AsyncData(:final value) => _Details(
          key: const ValueKey('fiche'),
          item: value,
          heroTag: heroTag,
          initialSeasonId: initialSeasonId,
        ),
        AsyncError(:final error) => Scaffold(
          key: const ValueKey('erreur'),
          body: Stack(
            children: [
              StatusMessage(
                icon: Icons.error_outline_rounded,
                text: error is ApiFailure ? error.userMessage : 'Impossible d’afficher cet élément.',
                onRetry: () => ref.invalidate(itemProvider(itemId)),
              ),
              const _BackButton(),
            ],
          ),
        ),
        _ => const Scaffold(
          key: ValueKey('chargement'),
          body: Stack(
            children: [
              Center(child: CircularProgressIndicator()),
              _BackButton(),
            ],
          ),
        ),
      },
    );
  }
}

/// Hauteur de l'en-tête immersif.
double detailsHeaderHeight(Size size) {
  final portrait = size.height > size.width;
  return portrait ? (size.height * 0.58).clamp(380, 680) : (size.height * 0.72).clamp(340, 720);
}

class _Details extends ConsumerStatefulWidget {
  const _Details({super.key, required this.item, required this.heroTag, required this.initialSeasonId});

  final MediaItem item;
  final String? heroTag;
  final String? initialSeasonId;

  @override
  ConsumerState<_Details> createState() => _DetailsState();
}

class _DetailsState extends ConsumerState<_Details> {
  final _scroll = ScrollController();
  Color? _accent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAccent());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadAccent() async {
    final ref0 = widget.item.backdrop ?? widget.item.primary;
    final url = ref.read(imageUrlBuilderProvider).maybe(ref0, logicalWidth: 24, devicePixelRatio: 1);
    if (url == null) return;
    final accent = await accentFromUrl(url);
    if (mounted && accent != null) setState(() => _accent = accent);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final size = MediaQuery.sizeOf(context);
    final headerHeight = detailsHeaderHeight(size);
    final gutter = OFSpacing.screenGutter(size.width);
    final wide = size.width >= 700;

    return AnimatedTheme(
      data: OFTheme.dark(accent: _accent ?? OFColors.accentFallback),
      duration: OFMotion.of(context).standard,
      child: Scaffold(
        body: EntranceScope(
          child: Stack(
            children: [
              CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(
                    child: _Header(
                      item: item,
                      height: headerHeight,
                      scroll: _scroll,
                      heroTag: widget.heroTag,
                      wide: wide,
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, OFSpacing.lg, gutter, 0),
                    sliver: SliverToBoxAdapter(
                      child: FadeSlideIn(
                        delay: staggerDelay(3),
                        child: _Summary(item: item),
                      ),
                    ),
                  ),
                  // Les sections arrivent en cascade sous les actions.
                  for (final (i, section) in [
                    if (item.kind == MediaKind.series)
                      SeasonsSection(series: item, initialSeasonId: widget.initialSeasonId),
                    if (item.kind == MediaKind.boxSet || item.kind == MediaKind.playlist) ChildrenSection(parent: item),
                    if (item.people.isNotEmpty) CastSection(people: item.people),
                    if (item.kind != MediaKind.episode) SimilarSection(itemId: item.id),
                    if (item.streams.isNotEmpty) TechnicalSection(item: item),
                  ].indexed)
                    SliverToBoxAdapter(
                      child: FadeSlideIn(delay: staggerDelay(i + 5), offset: 24, child: section),
                    ),
                  SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 120)),
                ],
              ),
              _TopBar(scroll: _scroll, title: item.name, fadeStart: headerHeight - 140),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.item,
    required this.height,
    required this.scroll,
    required this.heroTag,
    required this.wide,
  });

  final MediaItem item;
  final double height;
  final ScrollController scroll;
  final String? heroTag;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final images = ref.watch(imageUrlBuilderProvider);
    final gutter = OFSpacing.screenGutter(size.width);
    final backdropRef = item.kind == MediaKind.episode
        ? (item.primary ?? item.backdrop)
        : (item.backdrop ?? item.primary);
    final motion = OFMotion.of(context);

    Widget backdrop = OFImage(
      url: images.maybe(backdropRef, logicalWidth: size.width, devicePixelRatio: dpr),
      blurHash: backdropRef?.blurHash,
      decodeWidth: (size.width * dpr).ceil(),
    );
    // Téléphone : la carte source « zoome » vers le backdrop.
    if (!wide && heroTag != null) backdrop = Hero(tag: heroTag!, child: backdrop);

    final meta = MediaFormat.metadataLine(item);
    final badges = qualityBadges(item.streams);

    final titleBlock = Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.kind == MediaKind.episode && item.seriesName != null) ...[
          Text(
            item.seriesName!,
            style: OFTypography.callout.copyWith(color: OFColors.textSecondary),
            textAlign: wide ? TextAlign.start : TextAlign.center,
          ),
          const SizedBox(height: OFSpacing.xs),
        ],
        if (item.logo != null && item.kind != MediaKind.episode)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 380 : size.width * 0.7, maxHeight: height * 0.22),
            child: Semantics(
              label: item.name,
              header: true,
              child: OFImage(
                url: images.image(item.logo!, logicalWidth: wide ? 380 : size.width * 0.7, devicePixelRatio: dpr),
                fit: BoxFit.contain,
                transparentPlaceholder: true,
                fallback: _TitleText(item.name, wide: wide),
              ),
            ),
          )
        else
          _TitleText(
            item.kind == MediaKind.episode && item.episodeLabel != null
                ? '${item.episodeLabel} · ${item.name}'
                : item.name,
            wide: wide,
          ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: OFSpacing.md),
          Text(
            meta.join('  ·  '),
            style: OFTypography.callout.copyWith(color: OFColors.textSecondary),
            textAlign: wide ? TextAlign.start : TextAlign.center,
          ),
        ],
        if (badges.isNotEmpty) ...[
          const SizedBox(height: OFSpacing.md),
          Wrap(
            alignment: wide ? WrapAlignment.start : WrapAlignment.center,
            spacing: OFSpacing.sm,
            runSpacing: OFSpacing.sm,
            children: [for (final b in badges) QualityBadge(b)],
          ),
        ],
      ],
    );

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Parallaxe verticale : le fond défile à 40 % de la vitesse du contenu.
          ClipRect(
            child: AnimatedBuilder(
              animation: scroll,
              builder: (context, child) {
                final offset = scroll.hasClients ? scroll.offset : 0.0;
                if (!motion.enabled) return child!;
                if (offset < 0) {
                  // Sur-défilement iOS : léger zoom plutôt qu'un vide.
                  return Transform.scale(
                    scale: 1 + (-offset / height),
                    alignment: Alignment.bottomCenter,
                    child: child,
                  );
                }
                return Transform.translate(offset: Offset(0, offset * 0.4), child: child);
              },
              child: backdrop,
            ),
          ),
          const DecoratedBox(decoration: BoxDecoration(gradient: OFColors.scrim)),
          Positioned(
            left: gutter,
            right: gutter,
            bottom: OFSpacing.lg,
            child: FadeSlideIn(
              delay: staggerDelay(1),
              offset: 20,
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (item.poster != null) _Poster(item: item, heroTag: heroTag, width: 160),
                        if (item.poster != null) const SizedBox(width: OFSpacing.xl),
                        Expanded(child: titleBlock),
                      ],
                    )
                  : titleBlock,
            ),
          ),
        ],
      ),
    );
  }
}

class _Poster extends ConsumerWidget {
  const _Poster({required this.item, required this.heroTag, required this.width});

  final MediaItem item;
  final String? heroTag;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final image = OFImage(
      url: ref.watch(imageUrlBuilderProvider).maybe(item.poster, logicalWidth: width, devicePixelRatio: dpr),
      blurHash: item.poster?.blurHash,
      decodeWidth: (width * dpr).ceil(),
    );
    return Container(
      width: width,
      height: width * 1.5,
      decoration: const BoxDecoration(
        borderRadius: OFRadius.mdAll,
        boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: OFRadius.mdAll,
        child: heroTag == null ? image : Hero(tag: heroTag!, child: image),
      ),
    );
  }
}

class _TitleText extends StatelessWidget {
  const _TitleText(this.text, {required this.wide});

  final String text;
  final bool wide;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      textAlign: wide ? TextAlign.start : TextAlign.center,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: OFTypography.display,
    ),
  );
}

/// Actions + synopsis + informations.
class _Summary extends ConsumerWidget {
  const _Summary({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userStateProvider(item.id)) ?? item.user;
    final nextUp = item.kind == MediaKind.series ? ref.watch(nextUpForSeriesProvider(item.id)).value : null;
    final playTarget = nextUp ?? item;
    // Collections / playlists : lecture en file d'attente en phase 5.
    final canPlay = item.kind.isPlayableVideo || nextUp != null;
    final resumable = item.kind.isPlayableVideo && user.positionTicks > 0 && !user.played;
    // Préchargement de PlaybackInfo dès l'ouverture : la lecture démarre plus vite.
    if (playTarget.kind.isPlayableVideo) ref.watch(playbackPrefetchProvider(playTarget.id));
    final targetResumable = playTarget.user.positionTicks > 0 && !playTarget.user.played;
    final directors = item.people.where((p) => p.kind == PersonKind.director).toList();
    final writers = item.people.where((p) => p.kind == PersonKind.writer).toList();

    String playLabel() {
      final verb = targetResumable ? 'Reprendre' : 'Lecture';
      if (nextUp != null) return '$verb ${nextUp.episodeLabel ?? ''}'.trim();
      return verb;
    }

    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
      } on ApiFailure catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    }

    final controller = ref.read(userStateProvider(item.id).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: OFSpacing.md,
          runSpacing: OFSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (canPlay)
              OFButton(
                label: playLabel(),
                icon: Icons.play_arrow_rounded,
                onPressed: () => context.play(playTarget.id, start: targetResumable ? null : Duration.zero),
              ),
            if (canPlay && targetResumable)
              OFIconButton(
                icon: Icons.restart_alt_rounded,
                tooltip: 'Lire depuis le début',
                onPressed: () => context.play(playTarget.id, start: Duration.zero),
              ),
            if (item.kind != MediaKind.person)
              _ToggleIcon(
                active: user.played,
                icon: Icons.check_circle_outline_rounded,
                activeIcon: Icons.check_circle_rounded,
                label: user.played ? 'Marquer comme non vu' : 'Marquer comme vu',
                onTap: () => run(() => controller.togglePlayed(user)),
              ),
            _ToggleIcon(
              active: user.favorite,
              icon: Icons.favorite_border_rounded,
              activeIcon: Icons.favorite_rounded,
              label: user.favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
              onTap: () => run(() => controller.toggleFavorite(user)),
            ),
            if (item.trailers.isNotEmpty)
              OFIconButton(
                icon: Icons.movie_outlined,
                tooltip: 'Bande-annonce',
                onPressed: () => launchUrl(item.trailers.first.url, mode: LaunchMode.externalApplication),
              ),
          ],
        ),
        if (resumable && item.runtime != null) ...[
          const SizedBox(height: OFSpacing.lg),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                  child: LinearProgressIndicator(value: user.progress ?? 0, minHeight: 3),
                ),
              ),
              const SizedBox(width: OFSpacing.md),
              Text(
                MediaFormat.remaining(item) ?? '',
                style: OFTypography.caption.copyWith(color: OFColors.textSecondary),
              ),
            ],
          ),
        ],
        if (item.tagline != null) ...[
          const SizedBox(height: OFSpacing.xl),
          Text(item.tagline!, style: OFTypography.headline.copyWith(color: OFColors.textSecondary)),
        ],
        if (item.overview != null) ...[const SizedBox(height: OFSpacing.md), ExpandableText(item.overview!)],
        if (item.kind == MediaKind.episode && item.seriesId != null) ...[
          const SizedBox(height: OFSpacing.lg),
          OFButton.secondary(
            label: 'Voir la série',
            icon: Icons.tv_rounded,
            onPressed: () => context.openItemId(item.seriesId!),
          ),
        ],
        if (item.genres.isNotEmpty) ...[
          const SizedBox(height: OFSpacing.xl),
          Wrap(
            spacing: OFSpacing.sm,
            runSpacing: OFSpacing.sm,
            children: [
              for (final g in item.genres)
                ActionChip(
                  label: Text(g.name),
                  onPressed: () => context.openGenre(g),
                  backgroundColor: OFColors.surfaceRaised,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  labelStyle: OFTypography.callout,
                ),
            ],
          ),
        ],
        if (directors.isNotEmpty || writers.isNotEmpty || item.studios.isNotEmpty) ...[
          const SizedBox(height: OFSpacing.xl),
          if (directors.isNotEmpty) _InfoLine(label: 'Réalisation', people: directors),
          if (writers.isNotEmpty) _InfoLine(label: 'Scénario', people: writers),
          if (item.studios.isNotEmpty)
            _InfoLine.named(label: 'Studio', refs: item.studios.take(3).toList(), onTap: context.openStudio),
        ],
      ],
    );
  }
}

class _ToggleIcon extends StatelessWidget {
  const _ToggleIcon({
    required this.active,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: active,
      child: AnimatedSwitcher(
        duration: OFMotion.of(context).standard,
        transitionBuilder: (child, a) => ScaleTransition(
          scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: a, child: child),
        ),
        child: OFIconButton(key: ValueKey(active), icon: active ? activeIcon : icon, tooltip: label, onPressed: onTap),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  _InfoLine({required this.label, required List<PersonCredit> people})
    : refs = [for (final p in people) NamedRef(id: p.id, name: p.name)],
      onTap = null,
      isPeople = true;

  const _InfoLine.named({required this.label, required this.refs, required this.onTap}) : isPeople = false;

  final String label;
  final List<NamedRef> refs;
  final void Function(NamedRef)? onTap;
  final bool isPeople;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: OFSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(label, style: OFTypography.callout.copyWith(color: OFColors.textTertiary)),
          ),
          Expanded(
            child: Wrap(
              children: [
                for (final (i, r) in refs.indexed)
                  GestureDetector(
                    onTap: () => isPeople ? context.openPerson(r.id) : onTap?.call(r),
                    child: Text('${r.name}${i < refs.length - 1 ? ', ' : ''}', style: OFTypography.callout),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Texte replié sur 4 lignes avec « Plus ».
class ExpandableText extends StatefulWidget {
  const ExpandableText(this.text, {super.key, this.maxLines = 4});

  final String text;
  final int maxLines;

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    const style = OFTypography.body;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: widget.maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        return GestureDetector(
          onTap: overflows ? () => setState(() => _expanded = !_expanded) : null,
          child: AnimatedSize(
            duration: OFMotion.of(context).standard,
            curve: OFMotion.standardCurve,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.text,
                  style: style.copyWith(color: OFColors.textPrimary.withValues(alpha: 0.85)),
                  maxLines: _expanded ? null : widget.maxLines,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.fade,
                ),
                if (overflows)
                  Padding(
                    padding: const EdgeInsets.only(top: OFSpacing.xs),
                    child: Text(
                      _expanded ? 'Moins' : 'Plus',
                      style: OFTypography.callout.copyWith(color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Barre du haut : bouton retour flottant, puis barre en verre avec titre
/// quand l'en-tête a défilé.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.scroll, required this.title, required this.fadeStart});

  final ScrollController scroll;
  final String title;
  final double fadeStart;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnimatedBuilder(
      animation: scroll,
      builder: (context, _) {
        final offset = scroll.hasClients ? scroll.offset : 0.0;
        final t = ((offset - fadeStart) / 60).clamp(0.0, 1.0);
        return SizedBox(
          height: top + 56,
          child: Stack(
            children: [
              if (t > 0)
                Positioned.fill(
                  child: Opacity(
                    opacity: t,
                    child: GlassSurface(
                      borderRadius: BorderRadius.zero,
                      child: ColoredBox(
                        color: const Color(0xB3000000),
                        child: Padding(
                          padding: EdgeInsets.only(top: top, left: 64, right: 64),
                          child: Center(
                            child: Text(
                              title,
                              style: OFTypography.headline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const _BackButton(),
            ],
          ),
        );
      },
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    if (!context.canPop()) return const SizedBox.shrink();
    return Positioned(
      top: MediaQuery.paddingOf(context).top + OFSpacing.xs,
      left: OFSpacing.md,
      child: OFIconButton(icon: Icons.arrow_back_ios_new_rounded, tooltip: 'Retour', onPressed: () => context.pop()),
    );
  }
}

/// Style de carte pour les enfants d'une collection/playlist.
CardStyle childStyle(MediaItem parent) => parent.kind == MediaKind.playlist ? CardStyle.landscape : CardStyle.poster;
