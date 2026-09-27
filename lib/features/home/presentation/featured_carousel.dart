import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/media/formatters.dart';
import '../../../core/media/media_item.dart';
import '../../../core/providers.dart';

/// Hauteur du carrousel selon l'écran : immersif sur téléphone, borné sur tablette.
double featuredHeight(Size size) {
  final portrait = size.height > size.width;
  return portrait ? (size.height * 0.62).clamp(420, 720) : (size.height * 0.78).clamp(320, 640);
}

/// Grand carrousel « à la une » : backdrop plein cadre + logo + actions.
///
/// Parallaxe horizontale légère au swipe, défilement auto toutes les 8 s (désactivé
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
  int _index = 0;

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

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
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
    final size = MediaQuery.sizeOf(context);
    final height = featuredHeight(size);
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollStartNotification && n.dragDetails != null) _timer?.cancel();
              if (n is ScrollEndNotification) _restartTimer();
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.items.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                _updateAccent();
              },
              itemBuilder: (context, i) => _FeaturedPage(
                item: widget.items[i],
                index: i,
                controller: _controller,
                height: height,
              ),
            ),
          ),
          if (widget.items.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: OFSpacing.md,
              child: ExcludeSemantics(child: _Dots(count: widget.items.length, index: _index)),
            ),
        ],
      ),
    );
  }
}

class _FeaturedPage extends ConsumerWidget {
  const _FeaturedPage({required this.item, required this.index, required this.controller, required this.height});

  final MediaItem item;
  final int index;
  final PageController controller;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final images = ref.watch(imageUrlBuilderProvider);
    final gutter = OFSpacing.screenGutter(size.width);
    final backdrop = item.backdrop;
    final logo = item.logo;
    final meta = [
      ...item.genres.take(2).map((g) => g.name),
      ?MediaFormat.years(item),
    ].join(' · ');

    return Semantics(
      container: true,
      label: '${item.name}${meta.isEmpty ? '' : ', $meta'}',
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Parallaxe : l'image glisse moins vite que la page.
          ClipRect(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                final page = controller.hasClients && controller.position.haveDimensions ? controller.page ?? 0 : 0.0;
                return Transform.translate(offset: Offset((page - index) * size.width * 0.3, 0), child: child);
              },
              child: OFImage(
                url: images.maybe(backdrop, logicalWidth: size.width, devicePixelRatio: dpr),
                blurHash: backdrop?.blurHash,
                decodeWidth: (size.width * dpr).ceil(),
              ),
            ),
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
          Positioned(
            left: gutter,
            right: gutter,
            bottom: OFSpacing.xxxl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (logo != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: size.width * 0.62, maxHeight: height * 0.2),
                    child: OFImage(
                      url: images.image(logo, logicalWidth: size.width * 0.62, devicePixelRatio: dpr),
                      fit: BoxFit.contain,
                      fallback: _Title(item.name),
                    ),
                  )
                else
                  _Title(item.name),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: OFSpacing.md),
                  Text(meta, style: OFTypography.callout.copyWith(color: OFColors.textSecondary)),
                ],
                const SizedBox(height: OFSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OFButton(
                      label: 'Lecture',
                      icon: Icons.play_arrow_rounded,
                      onPressed: () => context.openItem(item),
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
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: OFTypography.display,
      );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final motion = OFMotion.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
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
