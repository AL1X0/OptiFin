import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/media/formatters.dart';
import '../../../core/media/media_item.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../../common/presentation/media_cards.dart';
import '../../home/domain/home_data.dart';
import '../domain/library_pager.dart';
import '../domain/library_query.dart';
import 'library_options_sheet.dart';
import 'library_providers.dart';

/// Parcours d'une bibliothèque, d'un genre ou d'un studio.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key, required this.source});

  final LibrarySource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(libraryContextProvider(source));
    return switch (ctx) {
      AsyncData(:final value) => _LibraryBrowser(key: ValueKey(source), context0: value),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: StatusMessage(
          text: error is ApiFailure ? error.userMessage : 'Bibliothèque indisponible.',
          onRetry: () => ref.invalidate(libraryContextProvider(source)),
        ),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _LibraryBrowser extends ConsumerStatefulWidget {
  const _LibraryBrowser({super.key, required this.context0});

  final LibraryContext context0;

  @override
  ConsumerState<_LibraryBrowser> createState() => _LibraryBrowserState();
}

class _LibraryBrowserState extends ConsumerState<_LibraryBrowser> {
  late LibraryQuery _query = widget.context0.query;
  late LibraryPager<MediaItem> _pager;
  final _scroll = ScrollController();
  bool _listMode = false;

  @override
  void initState() {
    super.initState();
    _pager = _createPager(_query);
  }

  @override
  void dispose() {
    _pager.dispose();
    _scroll.dispose();
    super.dispose();
  }

  LibraryPager<MediaItem> _createPager(LibraryQuery q) {
    final repo = ref.read(mediaRepositoryProvider);
    final pager = LibraryPager<MediaItem>((start, limit) => repo.page(q, start, limit));
    unawaited(pager.start());
    return pager;
  }

  void _setQuery(LibraryQuery q) {
    if (q == _query) return;
    setState(() {
      _query = q;
      _pager.dispose();
      _pager = _createPager(q);
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  _Geometry _geometry(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = OFSpacing.screenGutter(width);
    // Place pour l'index alphabétique à droite.
    final avail = width - gutter * 2 - (_query.supportsAlphaIndex ? 12 : 0);
    if (_listMode) return _Geometry(columns: 1, cardWidth: avail, rowExtent: 104, gutter: gutter);
    final style = widget.context0.style;
    final target = cardWidthFor(style, width);
    final columns = ((avail + OFSpacing.md) / (target + OFSpacing.md)).round().clamp(2, 12);
    final cardWidth = (avail - OFSpacing.md * (columns - 1)) / columns;
    final rowExtent = cardHeightFor(style, cardWidth) + OFSpacing.lg;
    return _Geometry(columns: columns, cardWidth: cardWidth, rowExtent: rowExtent, gutter: gutter);
  }

  Future<void> _jumpToLetter(String letter, _Geometry g) async {
    try {
      final index = await ref.read(mediaRepositoryProvider).indexOfLetter(_query, letter);
      if (!mounted || !_scroll.hasClients) return;
      unawaited(_pager.ensureLoaded(index));
      final offset = (index ~/ g.columns) * g.rowExtent;
      _scroll.jumpTo(offset.clamp(0, _scroll.position.maxScrollExtent));
    } on ApiFailure {
      // Saut non critique : on ignore silencieusement.
    }
  }

  Future<void> _openOptions() async {
    await showOFSheet<void>(
      context,
      builder: (_) => LibraryOptionsSheet(initial: _query, onChanged: _setQuery),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = _geometry(context);
    final topInset = MediaQuery.paddingOf(context).top + 64;
    final bottomInset = MediaQuery.paddingOf(context).bottom + 96;

    return Scaffold(
      body: ListenableBuilder(
        listenable: _pager,
        builder: (context, _) {
          final total = _pager.total;
          Widget body;
          if (_pager.error != null) {
            final e = _pager.error;
            body = StatusMessage(
              key: const ValueKey('erreur'),
              text: e is ApiFailure ? e.userMessage : 'Impossible de charger le contenu.',
              onRetry: _pager.retry,
            );
          } else if (total == null) {
            body = const Center(key: ValueKey('chargement'), child: CircularProgressIndicator());
          } else if (total == 0) {
            body = StatusMessage(
              key: const ValueKey('vide'),
              icon: Icons.filter_alt_off_rounded,
              text: _query.activeFilterCount > 0 ? 'Aucun résultat avec ces filtres.' : 'Cette bibliothèque est vide.',
            );
          } else {
            body = EntranceScope(
              key: ValueKey('grille-${_query.hashCode}-$_listMode'),
              child: Scrollbar(
                controller: _scroll,
                child: CustomScrollView(
                  controller: _scroll,
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        g.gutter,
                        topInset + OFSpacing.md,
                        g.gutter + (_query.supportsAlphaIndex ? 12 : 0),
                        bottomInset,
                      ),
                      sliver: _listMode
                          ? SliverFixedExtentList.builder(
                              itemExtent: g.rowExtent,
                              itemCount: total,
                              itemBuilder: (context, i) => FadeSlideIn(
                                delay: staggerDelay(i),
                                child: _ListRow(item: _pager.itemAt(i)),
                              ),
                            )
                          : SliverGrid.builder(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: g.columns,
                                mainAxisSpacing: OFSpacing.lg,
                                crossAxisSpacing: OFSpacing.md,
                                mainAxisExtent: g.rowExtent - OFSpacing.lg,
                              ),
                              itemCount: total,
                              itemBuilder: (context, i) {
                                final item = _pager.itemAt(i);
                                // Arrivée en diagonale (ligne + colonne), puis squelette → carte en fondu.
                                return FadeSlideIn(
                                  delay: staggerDelay(i ~/ g.columns + i % g.columns),
                                  child: FadeThroughSwitcher(
                                    child: item == null
                                        ? Align(
                                            key: const ValueKey('squelette'),
                                            alignment: Alignment.topCenter,
                                            child: SkeletonBox(
                                              width: g.cardWidth,
                                              aspectRatio: _aspect(widget.context0.style),
                                            ),
                                          )
                                        : MediaCard(
                                            key: ValueKey(item.id),
                                            item: item,
                                            style: widget.context0.style,
                                            width: g.cardWidth,
                                            heroScope: 'lib',
                                          ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Stack(
            children: [
              Positioned.fill(child: FadeThroughSwitcher(child: body)),
              if (_query.supportsAlphaIndex && (total ?? 0) > 40)
                Positioned(
                  right: 2,
                  top: topInset + OFSpacing.md,
                  bottom: bottomInset,
                  child: AlphabetIndex(onLetter: (l) => _jumpToLetter(l, g)),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _TopBar(
                  title: widget.context0.title,
                  subtitle: total == null ? null : '$total élément${total > 1 ? 's' : ''}',
                  filterCount: _query.activeFilterCount,
                  listMode: _listMode,
                  onToggleMode: () => setState(() => _listMode = !_listMode),
                  onOptions: _openOptions,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static double _aspect(CardStyle s) => switch (s) {
    CardStyle.poster => 2 / 3,
    CardStyle.square => 1,
    CardStyle.landscape => 16 / 9,
  };
}

class _Geometry {
  const _Geometry({required this.columns, required this.cardWidth, required this.rowExtent, required this.gutter});

  final int columns;
  final double cardWidth;
  final double rowExtent;
  final double gutter;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.filterCount,
    required this.listMode,
    required this.onToggleMode,
    required this.onOptions,
  });

  final String title;
  final String? subtitle;
  final int filterCount;
  final bool listMode;
  final VoidCallback onToggleMode;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final gutter = OFSpacing.screenGutter(MediaQuery.sizeOf(context).width);
    return GlassSurface(
      borderRadius: BorderRadius.zero,
      child: ColoredBox(
        color: const Color(0xB3000000),
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter - OFSpacing.sm, top + OFSpacing.sm, gutter - OFSpacing.sm, OFSpacing.sm),
          child: Row(
            children: [
              if (context.canPop())
                IconButton(
                  tooltip: 'Retour',
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => context.pop(),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(title, style: OFTypography.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (subtitle != null)
                      Text(subtitle!, style: OFTypography.caption.copyWith(color: OFColors.textTertiary)),
                  ],
                ),
              ),
              IconButton(
                tooltip: listMode ? 'Affichage grille' : 'Affichage liste',
                icon: Icon(listMode ? Icons.grid_view_rounded : Icons.view_list_rounded, size: 22),
                onPressed: onToggleMode,
              ),
              IconButton(
                tooltip: 'Trier et filtrer',
                onPressed: onOptions,
                icon: Badge(
                  isLabelVisible: filterCount > 0,
                  label: Text('$filterCount'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.tune_rounded, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListRow extends ConsumerWidget {
  const _ListRow({required this.item});

  final MediaItem? item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = this.item;
    if (item == null) {
      return const Row(
        children: [
          SkeletonBox(width: 60, aspectRatio: 2 / 3),
          SizedBox(width: OFSpacing.md),
          Expanded(child: SizedBox()),
        ],
      );
    }
    final images = ref.watch(imageUrlBuilderProvider);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final meta = MediaFormat.metadataLine(item).join(' · ');
    return Semantics(
      button: true,
      label: [item.name, meta].where((s) => s.isNotEmpty).join(', '),
      excludeSemantics: true,
      onTap: () => context.openItem(item),
      child: InkWell(
        onTap: () => context.openItem(item),
        borderRadius: OFRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: OFSpacing.xs),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: OFRadius.smAll,
                child: SizedBox(
                  width: 60,
                  height: 90,
                  child: OFImage(
                    url: images.maybe(item.poster, logicalWidth: 60, devicePixelRatio: dpr),
                    blurHash: item.poster?.blurHash,
                    decodeWidth: (60 * dpr).ceil(),
                    fallback: const ColoredBox(color: OFColors.surfaceRaised),
                  ),
                ),
              ),
              const SizedBox(width: OFSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: OFTypography.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (meta.isNotEmpty)
                      Text(meta, style: OFTypography.caption.copyWith(color: OFColors.textSecondary), maxLines: 1),
                  ],
                ),
              ),
              if (item.user.played) const Icon(Icons.check_circle_rounded, size: 18, color: OFColors.textTertiary),
              if (item.user.favorite)
                const Padding(
                  padding: EdgeInsets.only(left: OFSpacing.xs),
                  child: Icon(Icons.favorite_rounded, size: 18, color: OFColors.textTertiary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Index alphabétique vertical : toucher ou glisser pour sauter à une lettre.
class AlphabetIndex extends StatefulWidget {
  const AlphabetIndex({super.key, required this.onLetter});

  final ValueChanged<String> onLetter;

  static const letters = [
    '#',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  @override
  State<AlphabetIndex> createState() => _AlphabetIndexState();
}

class _AlphabetIndexState extends State<AlphabetIndex> {
  String? _active;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _select(double dy, double height) {
    final i = (dy / height * AlphabetIndex.letters.length).floor().clamp(0, AlphabetIndex.letters.length - 1);
    final letter = AlphabetIndex.letters[i];
    if (letter == _active) return;
    HapticFeedback.selectionClick();
    setState(() => _active = letter);
    // Pendant un glissé, on ne requête le serveur qu'une fois stabilisé.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () => widget.onLetter(letter));
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        return Semantics(
          label: 'Index alphabétique',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (d) => _select(d.localPosition.dy, h),
            onVerticalDragUpdate: (d) => _select(d.localPosition.dy, h),
            onVerticalDragEnd: (_) => setState(() => _active = null),
            onTapDown: (d) => _select(d.localPosition.dy, h),
            onTapUp: (_) => setState(() => _active = null),
            child: SizedBox(
              width: 18,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final l in AlphabetIndex.letters)
                    Text(
                      l,
                      style: OFTypography.caption.copyWith(
                        fontSize: 10,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: l == _active ? accent : OFColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
