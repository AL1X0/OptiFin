import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/media/formatters.dart';
import '../../../core/media/media_item.dart';
import '../../../core/providers.dart';
import '../../player/presentation/playback_providers.dart';

/// Au-delà, décoder plus large n'apporte rien à l'œil et coûte des images saccadées.
const _maxDecodeWidth = 2400;

int _decodeWidth(double logicalWidth, double dpr) => (logicalWidth * dpr).ceil().clamp(1, _maxDecodeWidth);

/// Largeur du logo : centré et large sur téléphone, plus sobre (à gauche) sur tablette.
double _logoWidth(double pageWidth, Size screen) =>
    screen.shortestSide >= 600 ? (pageWidth * 0.36).clamp(280.0, 460.0) : pageWidth * 0.62;

/// Hauteur du carrousel selon l'écran : immersif sur téléphone, borné sur tablette.
double featuredHeight(Size size) {
  final portrait = size.height > size.width;
  return portrait ? (size.height * 0.62).clamp(420, 720) : (size.height * 0.78).clamp(320, 640);
}

/// Grand carrousel « à la une » : backdrop plein cadre + logo + actions.
///
/// Swipe entre les titres, défilement auto toutes les 8 s (désactivé
/// avec « Réduire les animations » et pendant une interaction), accent dynamique.
class FeaturedCarousel extends ConsumerStatefulWidget {
  const FeaturedCarousel({super.key, required this.items, required this.onAccent});

  final List<MediaItem> items;
  final ValueChanged<Color?> onAccent;

  @override
  ConsumerState<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends ConsumerState<FeaturedCarousel> {
  final _controller = PageController();
  Timer? _timer;

  /// Page courante : seuls les points s'y abonnent (pas de reconstruction du carrousel au swipe).
  final _page = ValueNotifier<int>(0);

  int get _index => _page.value;

  /// Largeur réelle d'une page (≠ largeur d'écran quand un rail latéral est affiché).
  double _pageWidth = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateAccent());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restartTimer();
  }

  /// Travail « lourd » (accent → animation du thème de tout l'accueil, décodage
  /// des voisines) fait une fois la page posée, jamais pendant le glissement :
  /// c'était la cause de l'à-coup en fin de swipe.
  void _onSettled() {
    _updateAccent();
    _precacheAround(_index);
    _prefetchPlayback();
  }

  /// « Lecture » lance directement le film : son plan de lecture (PlaybackInfo, choix du
  /// moteur) est préparé dès que la page est affichée, comme sur une fiche.
  void _prefetchPlayback() {
    if (widget.items.isEmpty) return;
    final item = widget.items[_index];
    if (item.kind.isPlayableVideo) ref.read(playbackPrefetchProvider(item.id));
  }

  /// Précharge backdrop + logo de la page courante et des voisines (même clé de
  /// cache que l'affichage) : au swipe ou au défilement auto, l'image est déjà décodée.
  void _precacheAround(int index) {
    final n = widget.items.length;
    if (n == 0) return;
    final width = _pageWidth;
    if (width <= 0) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final images = ref.read(imageUrlBuilderProvider);
    for (final i in {index, (index + 1) % n, (index - 1 + n) % n}) {
      final item = widget.items[i];
      final backdrop = images.maybe(item.backdrop, logicalWidth: width, devicePixelRatio: dpr);
      if (backdrop != null) {
        precacheImage(OFImage.provider(backdrop, decodeWidth: _decodeWidth(width, dpr)), context, onError: (_, _) {});
      }
      final logoWidth = _logoWidth(width, MediaQuery.sizeOf(context));
      final logo = images.maybe(item.logo, logicalWidth: logoWidth, devicePixelRatio: dpr);
      if (logo != null) precacheImage(OFImage.provider(logo), context, onError: (_, _) {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _page.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!OFMotion.of(context).enabled || widget.items.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.items.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 300), curve: OFMotion.standardCurve);
    });
  }

  Future<void> _updateAccent() async {
    if (widget.items.isEmpty || !mounted) return;
    final item = widget.items[_index];
    final url = ref.read(imageUrlBuilderProvider).maybe(item.backdrop, logicalWidth: 24, devicePixelRatio: 1);
    final accent = url == null ? null : await accentFromUrl(url);
    if (mounted && widget.items[_index].id == item.id) widget.onAccent(accent);
  }

  @override
  Widget build(BuildContext context) {
    final height = featuredHeight(MediaQuery.sizeOf(context));
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
          if (width != _pageWidth) {
            final first = _pageWidth == 0;
            _pageWidth = width;
            if (first) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _precacheAround(_index);
                _prefetchPlayback();
              });
            }
          }
          return Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is ScrollStartNotification && n.dragDetails != null) _timer?.cancel();
                  if (n is ScrollEndNotification) {
                    _restartTimer();
                    _onSettled();
                  }
                  return false;
                },
                child: RepaintBoundary(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: widget.items.length,
                    onPageChanged: (i) => _page.value = i,
                    itemBuilder: (context, i) => _FeaturedPage(item: widget.items[i], width: width, height: height),
                  ),
                ),
              ),
              if (widget.items.length > 1)
                Positioned(
                  left: tablet ? OFSpacing.screenGutter(width) - 3 : 0,
                  right: 0,
                  bottom: tablet ? OFSpacing.xl : OFSpacing.md,
                  child: ExcludeSemantics(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _page,
                      builder: (_, index, _) => _Dots(count: widget.items.length, index: index, start: tablet),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FeaturedPage extends ConsumerWidget {
  const _FeaturedPage({required this.item, required this.width, required this.height});

  final MediaItem item;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final images = ref.watch(imageUrlBuilderProvider);
    final gutter = OFSpacing.screenGutter(width);
    final backdrop = item.backdrop;
    final logo = item.logo;
    final meta = [...item.genres.take(2).map((g) => g.name), ?MediaFormat.years(item)].join(' · ');
    // Tablette : bloc titre à gauche (à la manière de l'Apple TV), l'illustration respire à droite.
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final logoWidth = _logoWidth(width, MediaQuery.sizeOf(context));
    final align = tablet ? CrossAxisAlignment.start : CrossAxisAlignment.center;

    return Semantics(
      container: true,
      label: '${item.name}${meta.isEmpty ? '' : ', $meta'}',
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Illustration solidaire de sa page (pas de parallaxe : au relâcher du doigt, l'image
          // donnait l'impression de « revenir en arrière » en rattrapant la page).
          OFImage(
            url: images.maybe(backdrop, logicalWidth: width, devicePixelRatio: dpr),
            blurHash: backdrop?.blurHash,
            decodeWidth: _decodeWidth(width, dpr),
          ),
          const DecoratedBox(decoration: BoxDecoration(gradient: OFColors.scrim)),
          // Voile haut pour la lisibilité de la barre d'état.
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
          if (tablet)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color(0x99000000), Color(0x00000000)], stops: [0, 0.6]),
              ),
            ),
          Positioned(
            left: gutter,
            right: tablet ? width * 0.45 : gutter,
            bottom: tablet ? OFSpacing.xxxl + OFSpacing.lg : OFSpacing.xxxl,
            child: Column(
              crossAxisAlignment: align,
              children: [
                if (logo != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: logoWidth, maxHeight: height * 0.2),
                    child: OFImage(
                      url: images.image(logo, logicalWidth: logoWidth, devicePixelRatio: dpr),
                      fit: BoxFit.contain,
                      alignment: tablet ? Alignment.bottomLeft : Alignment.center,
                      transparentPlaceholder: true,
                      fallback: _Title(item.name, start: tablet),
                    ),
                  )
                else
                  _Title(item.name, start: tablet),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: OFSpacing.md),
                  Text(meta, style: OFTypography.callout.copyWith(color: OFColors.textSecondary)),
                ],
                const SizedBox(height: OFSpacing.lg),
                Row(
                  mainAxisAlignment: tablet ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    OFButton(
                      label: 'Lecture',
                      icon: Icons.play_arrow_rounded,
                      // Film : lecture directe. Série : la fiche choisit l'épisode à suivre.
                      onPressed: () => item.kind.isPlayableVideo ? context.play(item.id) : context.openItem(item),
                    ),
                    const SizedBox(width: OFSpacing.md),
                    OFButton.secondary(
                      label: 'Infos',
                      icon: Icons.info_outline_rounded,
                      onPressed: () => context.openItem(item),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text, {this.start = false});

  final String text;

  /// Aligné à gauche (tablette).
  final bool start;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: start ? TextAlign.start : TextAlign.center,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: OFTypography.display,
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index, this.start = false});

  final int count;
  final int index;
  final bool start;

  @override
  Widget build(BuildContext context) {
    final motion = OFMotion.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: start ? MainAxisAlignment.start : MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: motion.standard,
            curve: OFMotion.standardCurve,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? accent : OFColors.textTertiary,
              borderRadius: const BorderRadius.all(Radius.circular(3)),
            ),
          ),
      ],
    );
  }
}
