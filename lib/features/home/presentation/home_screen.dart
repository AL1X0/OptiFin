import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/presentation/account_switcher.dart';
import '../../syncplay/presentation/watch_party_sheet.dart';
import '../../common/presentation/media_cards.dart';
import '../domain/home_data.dart';
import '../../downloads/presentation/downloads_providers.dart';
import 'featured_carousel.dart';
import 'home_providers.dart';

/// Accueil : carrousel « à la une » puis rangées (Reprendre, À suivre,
/// Ajouts récents par bibliothèque, Favoris).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// TV : le focus revient sur le carrousel (▲ depuis la première rangée) → la page remonte
  /// tout en haut, pas seulement jusqu'au bouton Lecture.
  void _toTop(bool focused) {
    if (!focused || !_scroll.hasClients || _scroll.offset <= 0) return;
    unawaited(_scroll.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic));
  }

  @override
  void initState() {
    super.initState();
    // Moteur de téléchargement démarré dès l'accueil (reprise des transferts, états
    // rattrapés) : son initialisation n'est plus sur le chemin du bouton Lecture.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        ref.read(downloadsRepositoryProvider);
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    final data = home.value;
    final gutter = OFSpacing.gutterOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom + 80; // barre d'onglets

    Widget content;
    if (data == null && home.hasError) {
      final error = home.error;
      content = StatusMessage(
        key: const ValueKey('erreur'),
        icon: Icons.cloud_off_rounded,
        text: error is ApiFailure ? error.userMessage : 'Impossible de charger l’accueil.',
        onRetry: () => ref.invalidate(homeProvider),
      );
    } else if (data == null) {
      content = const _HomeSkeleton(key: ValueKey('squelette'));
    } else if (data.isEmpty) {
      content = const StatusMessage(
        key: ValueKey('vide'),
        icon: Icons.movie_filter_outlined,
        text: 'Votre serveur ne contient encore rien à afficher.',
      );
    } else {
      content = EntranceScope(
        key: const ValueKey('contenu'),
        child: RefreshIndicator(
          edgeOffset: MediaQuery.paddingOf(context).top,
          onRefresh: () async {
            ref.invalidate(homeProvider);
            await ref.read(homeProvider.future);
          },
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              if (data.featured.isNotEmpty)
                SliverToBoxAdapter(
                  child: Focus(
                    canRequestFocus: false,
                    skipTraversal: true,
                    onFocusChange: OFDevice.tv ? _toTop : null,
                    child: FeaturedCarousel(items: data.featured, upcoming: data.upcoming),
                  ),
                )
              else
                SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).top + 72)),
              SliverPadding(
                padding: EdgeInsets.only(top: OFSpacing.xl, bottom: bottomInset),
                sliver: SliverList.separated(
                  itemCount: data.sections.length,
                  separatorBuilder: (_, _) => const SizedBox(height: OFSpacing.xxl),
                  itemBuilder: (context, i) {
                    final s = data.sections[i];
                    // Les rangées montent l'une après l'autre sous le carrousel.
                    return FadeSlideIn(
                      key: ValueKey(s.id),
                      delay: staggerDelay(i + 2),
                      offset: 24,
                      child: MediaItemsRow(
                        title: s.title,
                        items: s.items,
                        style: s.style,
                        heroScope: 'home-${s.id}',
                        onSeeAll: s.library == null ? null : () => context.openItem(s.library!),
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

    // Thème neutre : chaque film garde sa couleur pour lui (points du carrousel,
    // barres de progression), sans teinter tout l'accueil.
    return Scaffold(
      body: Stack(
        children: [
          // Squelette → contenu : fondu enchaîné plutôt qu'un remplacement sec.
          Positioned.fill(child: FadeThroughSwitcher(child: content)),
          // TV : soirée et compte sont dans le menu latéral (atteignables à la télécommande).
          if (!OFDevice.tv)
            Positioned(
              top: MediaQuery.paddingOf(context).top + OFSpacing.sm,
              right: gutter,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [WatchPartyButton(), SizedBox(width: OFSpacing.sm), AccountButton()],
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        SkeletonBox(height: featuredHeight(size), radius: BorderRadius.zero),
        const SizedBox(height: OFSpacing.xl),
        const SkeletonRow(style: CardStyle.landscape),
        const SizedBox(height: OFSpacing.xxl),
        const SkeletonRow(style: CardStyle.poster),
      ],
    );
  }
}
