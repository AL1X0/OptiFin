import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/media/formatters.dart';
import '../../../core/media/media_item.dart';
import '../../../core/network/image_url.dart';
import '../../../core/providers.dart';
import '../../player/presentation/playback_providers.dart';

/// Au-delà, décoder plus large n'apporte rien à l'œil et coûte des images saccadées.
const _maxDecodeWidth = 2400;

int _decodeWidth(double logicalWidth, double dpr) => (logicalWidth * dpr).ceil().clamp(1, _maxDecodeWidth);

/// Illustration plein écran du carrousel : WebP qualité 75, visuellement identique à
/// cette taille et nettement plus léger (chargement plus rapide).
Uri? _backdropUrl(JellyfinImageUrlBuilder images, MediaItem item, double width, double dpr) =>
    images.maybe(item.backdrop, logicalWidth: width, devicePixelRatio: dpr, quality: 75);

/// Largeur du logo : centré et large sur téléphone, plus sobre (à gauche) sur tablette.
double _logoWidth(double pageWidth, {required bool large}) =>
    large ? (pageWidth * 0.36).clamp(280.0, 460.0) : pageWidth * 0.62;

/// Hauteur du carrousel selon l'écran : immersif sur téléphone, borné sur tablette.
double featuredHeight(Size size) {
  final portrait = size.height > size.width;
  return portrait ? (size.height * 0.62).clamp(420, 720) : (size.height * 0.78).clamp(320, 640);
}

/// Grand carrousel « à la une » : backdrop plein cadre + logo + actions.
///
/// Swipe entre les titres, défilement auto toutes les 8 s (désactivé
/// avec « Réduire les animations » et pendant une interaction). Les points prennent la
/// couleur du titre affiché, sans teinter le reste de l'accueil.
class FeaturedCarousel extends ConsumerStatefulWidget {
  const FeaturedCarousel({super.key, required this.items, this.upcoming = const []});

  final List<MediaItem> items;

  /// Sélection de la prochaine ouverture : images téléchargées d'avance sur le disque.
  final List<MediaItem> upcoming;

  @override
  ConsumerState<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends ConsumerState<FeaturedCarousel> {
  final _controller = PageController();
  Timer? _timer;

  /// Page courante : seuls les points s'y abonnent (pas de reconstruction du carrousel au swipe).
  final _page = ValueNotifier<int>(0);

  /// Accent du titre affiché (points du carrousel uniquement).
  final _accent = ValueNotifier<Color?>(null);

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

  /// Travail « lourd » (accent des points, décodage
  /// des voisines) fait une fois la page posée, jamais pendant le glissement :
  /// c'était la cause de l'à-coup en fin de swipe.
  void _onSettled() {
    _updateAccent();
    _precacheAround(_index);
    _prefetchPlayback();
  }

  @override
  void didUpdateWidget(FeaturedCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // La sélection suivante arrive avec la réponse réseau, après le cache.
    if (_pageWidth > 0 && oldWidget.upcoming != widget.upcoming) _warmUpcoming();
  }

  bool _warmed = false;

  /// Télécharge (disque seulement, sans décoder) les illustrations et logos du carrousel
  /// de la prochaine ouverture, quelques secondes après l'affichage : elles seront
  /// alors servies depuis le cache, instantanément.
  void _warmUpcoming() {
    if (_warmed || widget.upcoming.isEmpty || OFImageSource.isOverridden) return;
    _warmed = true;
    final width = _pageWidth;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final large = OFDevice.large(context);
    final images = ref.read(imageUrlBuilderProvider);
    Future<void>.delayed(const Duration(seconds: 3), () async {
      for (final item in widget.upcoming) {
        if (!mounted) return;
        for (final url in [
          _backdropUrl(images, item, width, dpr),
          images.maybe(
            item.logo,
            logicalWidth: _logoWidth(width, large: large),
            devicePixelRatio: dpr,
          ),
        ]) {
          if (url == null) continue;
          try {
            await DefaultCacheManager().downloadFile(url.toString());
          } catch (_) {}
        }
      }
    });
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
      final backdrop = _backdropUrl(images, item, width, dpr);
      if (backdrop != null) {
        precacheImage(OFImage.provider(backdrop, decodeWidth: _decodeWidth(width, dpr)), context, onError: (_, _) {});
      }
      final logoWidth = _logoWidth(width, large: OFDevice.large(context));
      final logo = images.maybe(item.logo, logicalWidth: logoWidth, devicePixelRatio: dpr);
      if (logo != null) precacheImage(OFImage.provider(logo), context, onError: (_, _) {});
    }
  }

  /// Télécommande : bouton « Lecture » de chaque page (le focus y revient au changement de page).
  final _playNodes = <int, FocusNode>{};
  FocusNode _playNode(int i) => _playNodes.putIfAbsent(i, () => FocusNode(debugLabel: 'Lecture $i'));

  /// ◀ sur « Lecture » / ▶ sur « Infos » : titre précédent / suivant.
  bool _step(int delta) {
    final target = _index + delta;
    if (target < 0 || target >= widget.items.length || !_controller.hasClients) return false;
    unawaited(
      _controller
          .animateToPage(target, duration: const Duration(milliseconds: 350), curve: OFMotion.standardCurve)
          .then((_) {
            if (mounted) _playNode(target).requestFocus();
          }),
    );
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _page.dispose();
    _accent.dispose();
    for (final n in _playNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    // TV : pas de défilement automatique (il déroberait le focus de la télécommande).
    if (!OFMotion.of(context).enabled || widget.items.length < 2 || OFDevice.tv) return;
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
    if (mounted && widget.items[_index].id == item.id) _accent.value = accent;
  }

  @override
  Widget build(BuildContext context) {
    final height = featuredHeight(MediaQuery.sizeOf(context));
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final tablet = OFDevice.large(context);
          if (width != _pageWidth) {
            final first = _pageWidth == 0;
            _pageWidth = width;
            if (first) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _precacheAround(_index);
                _prefetchPlayback();
                _warmUpcoming();
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
                    itemBuilder: (context, i) => _FeaturedPage(
                      item: widget.items[i],
                      width: width,
                      height: height,
                      playFocus: _playNode(i),
                      autofocus: OFDevice.tv && i == 0,
                      onStep: _step,
                    ),
                  ),
                ),
              ),
              if (widget.items.length > 1)
                Positioned(
                  left: tablet ? OFSpacing.gutterOf(context) - 3 : 0,
                  right: 0,
                  bottom: tablet ? OFSpacing.xl : OFSpacing.md,
                  child: ExcludeSemantics(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _page,
                      builder: (_, index, _) => ValueListenableBuilder<Color?>(
                        valueListenable: _accent,
                        builder: (_, accent, _) =>
                            _Dots(count: widget.items.length, index: index, start: tablet, color: accent),
                      ),
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
  const _FeaturedPage({
    required this.item,
    required this.width,
    required this.height,
    required this.playFocus,
    required this.onStep,
    this.autofocus = false,
  });

  final MediaItem item;
  final double width;
  final double height;
  final FocusNode playFocus;
  final bool autofocus;

  /// Télécommande : titre précédent (-1) ou suivant (+1) ; false en bout de carrousel.
  final bool Function(int delta) onStep;

  /// ◀ ou ▶ au bord de la rangée de boutons : change de titre plutôt que de sortir.
  KeyEventResult Function(FocusNode, KeyEvent) _edge(LogicalKeyboardKey key, int delta) =>
      (_, event) => event is KeyDownEvent && event.logicalKey == key && onStep(delta)
      ? KeyEventResult.handled
      : KeyEventResult.ignored;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final images = ref.watch(imageUrlBuilderProvider);
    final gutter = OFSpacing.gutterOf(context);
    final backdrop = item.backdrop;
    final logo = item.logo;
    final meta = [...item.genres.take(2).map((g) => g.name), ?MediaFormat.years(item)].join(' · ');
    // Tablette : bloc titre à gauche (à la manière de l'Apple TV), l'illustration respire à droite.
    final tablet = OFDevice.large(context);
    final logoWidth = _logoWidth(width, large: OFDevice.large(context));
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
            url: _backdropUrl(images, item, width, dpr),
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
                    Focus(
                      canRequestFocus: false,
                      skipTraversal: true,
                      onKeyEvent: _edge(LogicalKeyboardKey.arrowLeft, -1),
                      child: OFButton(
                        label: 'Lecture',
                        icon: Icons.play_arrow_rounded,
                        focusNode: playFocus,
                        autofocus: autofocus,
                        // Film : lecture directe. Série : la fiche choisit l'épisode à suivre.
                        onPressed: () => item.kind.isPlayableVideo ? context.play(item.id) : context.openItem(item),
                      ),
                    ),
                    const SizedBox(width: OFSpacing.md),
                    Focus(
                      canRequestFocus: false,
                      skipTraversal: true,
                      onKeyEvent: _edge(LogicalKeyboardKey.arrowRight, 1),
                      child: OFButton.secondary(
                        label: 'Infos',
                        icon: Icons.info_outline_rounded,
                        onPressed: () => context.openItem(item),
                      ),
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
  const _Dots({required this.count, required this.index, this.start = false, this.color});

  /// Accent du titre affiché ; null = accent de l'app.
  final Color? color;

  final int count;
  final int index;
  final bool start;

  @override
  Widget build(BuildContext context) {
    final motion = OFMotion.of(context);
    final accent = color ?? Theme.of(context).colorScheme.primary;
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
