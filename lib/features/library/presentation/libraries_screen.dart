import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../app/navigation.dart';
import '../../../app/router.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../../auth/presentation/account_switcher.dart';
import '../../common/presentation/media_cards.dart';
import 'library_providers.dart';

/// Onglet Bibliothèques : grille des vues de l'utilisateur.
class LibrariesScreen extends ConsumerWidget {
  const LibrariesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(userViewsProvider);
    final size = MediaQuery.sizeOf(context);
    final gutter = OFSpacing.screenGutter(size.width);
    final columns = size.width >= 1024 ? 4 : (size.width >= 600 ? 3 : 2);
    final cardWidth = (size.width - gutter * 2 - OFSpacing.md * (columns - 1)) / columns;
    final images = ref.watch(imageUrlBuilderProvider);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, OFSpacing.lg, gutter, OFSpacing.xl),
              sliver: const SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(child: Text('Bibliothèques', style: OFTypography.title1)),
                    _SettingsButton(),
                    SizedBox(width: OFSpacing.md),
                    AccountButton(),
                  ],
                ),
              ),
            ),
          ),
          switch (views) {
            AsyncData(:final value) when value.isEmpty =>
              const SliverFillRemaining(child: StatusMessage(text: 'Aucune bibliothèque.')),
            AsyncData(:final value) => SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, MediaQuery.paddingOf(context).bottom + 96),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: OFSpacing.lg,
                    crossAxisSpacing: OFSpacing.md,
                    childAspectRatio: cardWidth / (cardWidth * 9 / 16 + 28),
                  ),
                  itemCount: value.length,
                  itemBuilder: (context, i) {
                    final v = value[i];
                    final image = v.primary ?? v.landscape;
                    return LandscapeCard(
                      width: cardWidth,
                      data: MediaCardData(
                        id: v.id,
                        title: v.name,
                        imageUrl: images.maybe(image, logicalWidth: cardWidth, devicePixelRatio: dpr),
                        blurHash: image?.blurHash,
                      ),
                      onTap: () => context.openLibrary(v.id),
                    );
                  },
                ),
              ),
            AsyncError(:final error) => SliverFillRemaining(
                child: StatusMessage(
                  text: error is ApiFailure ? error.userMessage : 'Impossible de charger les bibliothèques.',
                  onRetry: () => ref.invalidate(userViewsProvider),
                ),
              ),
            _ => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
          },
        ],
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context) =>
      OFIconButton(icon: Icons.settings_outlined, tooltip: 'Paramètres', onPressed: () => context.push(Routes.settings));
}
