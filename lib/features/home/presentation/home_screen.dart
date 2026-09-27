import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/presentation/account_switcher.dart';
import '../../common/presentation/media_cards.dart';
import '../domain/home_data.dart';
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
  Color? _accent;

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    final data = home.value;
    final gutter = OFSpacing.screenGutter(MediaQuery.sizeOf(context).width);
    final bottomInset = MediaQuery.paddingOf(context).bottom + 80; // barre d'onglets

    Widget content;
    if (data == null && home.hasError) {
      final error = home.error;
      content = StatusMessage(
        icon: Icons.cloud_off_rounded,
        text: error is ApiFailure ? error.userMessage : 'Impossible de charger l’accueil.',
        onRetry: () => ref.invalidate(homeProvider),
      );
    } else if (data == null) {
      content = const _HomeSkeleton();
    } else if (data.isEmpty) {
      content = const StatusMessage(
        icon: Icons.movie_filter_outlined,
        text: 'Votre serveur ne contient encore rien à afficher.',
      );
    } else {
      content = RefreshIndicator(
        edgeOffset: MediaQuery.paddingOf(context).top,
        onRefresh: () async {
          ref.invalidate(homeProvider);
          await ref.read(homeProvider.future);
        },
        child: CustomScrollView(
          slivers: [
            if (data.featured.isNotEmpty)
              SliverToBoxAdapter(
                child: FeaturedCarousel(
                  items: data.featured,
                  onAccent: (c) {
                    if (c != _accent) setState(() => _accent = c);
                  },
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
                  return MediaItemsRow(
                    key: ValueKey(s.id),
                    title: s.title,
                    items: s.items,
                    style: s.style,
                    heroScope: 'home-${s.id}',
                    onSeeAll: s.library == null ? null : () => context.openItem(s.library!),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedTheme(
      data: OFTheme.dark(accent: _accent ?? OFColors.accentFallback),
      duration: OFMotion.of(context).standard,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: content),
            Positioned(
              top: MediaQuery.paddingOf(context).top + OFSpacing.sm,
              right: gutter,
              child: const AccountButton(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

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
