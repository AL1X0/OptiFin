import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/media/media_item.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../../common/presentation/media_cards.dart';
import '../../details/presentation/item_details_screen.dart';
import '../../home/domain/home_data.dart';
import '../../library/domain/library_query.dart';

final personProvider = FutureProvider.autoDispose.family<MediaItem, String>(
  (ref, id) => ref.watch(mediaRepositoryProvider).person(id),
);

/// Filmographie : films et séries, du plus récent au plus ancien.
final filmographyProvider = FutureProvider.autoDispose.family<List<MediaItem>, String>((ref, id) async {
  final page = await ref
      .watch(mediaRepositoryProvider)
      .page(
        LibraryQuery(
          personIds: [id],
          kinds: const [MediaKind.movie, MediaKind.series],
          sort: LibrarySort.premiereDate,
          descending: true,
        ),
        0,
        300,
      );
  return page.items;
});

class PersonScreen extends ConsumerWidget {
  const PersonScreen({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(personProvider(personId));
    final films = ref.watch(filmographyProvider(personId));
    final size = MediaQuery.sizeOf(context);
    final gutter = OFSpacing.gutterOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final images = ref.watch(imageUrlBuilderProvider);
    final target = cardWidthFor(CardStyle.poster, size.width);
    final avail = size.width - gutter * 2;
    final columns = ((avail + OFSpacing.md) / (target + OFSpacing.md)).round().clamp(2, 12);
    final cardWidth = (avail - OFSpacing.md * (columns - 1)) / columns;

    return Scaffold(
      body: EntranceScope(
        window: const Duration(milliseconds: 1500),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: OFColors.background.withValues(alpha: 0.9),
              leading: context.canPop()
                  ? IconButton(
                      tooltip: 'Retour',
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      onPressed: () => context.pop(),
                    )
                  : null,
              title: Text(person.value?.name ?? '', style: OFTypography.headline),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, OFSpacing.lg, gutter, 0),
              sliver: SliverToBoxAdapter(
                child: switch (person) {
                  AsyncData(:final value) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AvatarChip(
                        name: value.name,
                        size: 112,
                        imageUrl: images.maybe(value.primary, logicalWidth: 112, devicePixelRatio: dpr),
                      ),
                      const SizedBox(width: OFSpacing.xl),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(header: true, child: Text(value.name, style: OFTypography.title1)),
                            if (value.premiereDate != null)
                              Text(
                                'Né(e) en ${value.premiereDate!.year}',
                                style: OFTypography.callout.copyWith(color: OFColors.textSecondary),
                              ),
                            if (value.overview != null) ...[
                              const SizedBox(height: OFSpacing.md),
                              ExpandableText(value.overview!, maxLines: 5),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  AsyncError(:final error) => StatusMessage(
                    text: error is ApiFailure ? error.userMessage : 'Personne introuvable.',
                    onRetry: () => ref.invalidate(personProvider(personId)),
                  ),
                  _ => const SizedBox(height: 112, child: Center(child: OFLoader())),
                },
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, OFSpacing.xxl, gutter, OFSpacing.md),
              sliver: const SliverToBoxAdapter(child: Text('Filmographie', style: OFTypography.title2)),
            ),
            switch (films) {
              AsyncData(:final value) when value.isEmpty => const SliverToBoxAdapter(
                child: StatusMessage(text: 'Aucun titre dans votre bibliothèque.'),
              ),
              AsyncData(:final value) => SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, MediaQuery.paddingOf(context).bottom + 96),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: OFSpacing.lg,
                    crossAxisSpacing: OFSpacing.md,
                    mainAxisExtent: cardHeightFor(CardStyle.poster, cardWidth),
                  ),
                  itemCount: value.length,
                  itemBuilder: (context, i) => FadeSlideIn(
                    delay: staggerDelay(i ~/ columns + i % columns),
                    child: MediaCard(item: value[i], style: CardStyle.poster, width: cardWidth, heroScope: 'person'),
                  ),
                ),
              ),
              AsyncError() => SliverToBoxAdapter(
                child: StatusMessage(
                  text: 'Impossible de charger la filmographie.',
                  onRetry: () => ref.invalidate(filmographyProvider(personId)),
                ),
              ),
              _ => const SliverToBoxAdapter(child: Center(child: OFLoader())),
            },
          ],
        ),
      ),
    );
  }
}
