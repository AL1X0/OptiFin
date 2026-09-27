import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_api/jellyfin_api.dart';

import '../../../app/router.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/image_url.dart';
import '../../../core/providers.dart';
import '../../auth/data/account_store.dart';

/// Bibliothèques de l'utilisateur (phase 1 : preuve de bout en bout de l'API authentifiée).
final userViewsProvider = FutureProvider.autoDispose<List<BaseItemDto>>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  if (session == null) return const [];
  try {
    final result = await ref.watch(jellyfinClientProvider).userView.getUserViews(userId: session.account.userId);
    return result.items ?? const [];
  } catch (e) {
    throw ApiFailure.from(e);
  }
});

/// Accueil — squelette de phase 1. Le carrousel « à la une » et les rangées
/// Reprendre / À suivre / Ajouts récents arrivent en phase 2.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session == null) return const Scaffold();
    final views = ref.watch(userViewsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final gutter = OFSpacing.screenGutter(width);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final images = ref.watch(imageUrlBuilderProvider);
    final cardWidth = OFBreakpoint.of(width).posterWidth * 1.9;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(userViewsProvider.future),
        child: CustomScrollView(
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, OFSpacing.lg, gutter, OFSpacing.xl),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: const Text('Accueil', style: OFTypography.title1),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Changer de compte, connecté en tant que ${session.account.userName}',
                        excludeSemantics: true,
                        onTap: () => showOFSheet<void>(context, builder: (_) => const AccountSwitcherSheet()),
                        child: GestureDetector(
                          onTap: () => showOFSheet<void>(context, builder: (_) => const AccountSwitcherSheet()),
                          child: AvatarChip(
                            name: session.account.userName,
                            size: 36,
                            imageUrl: session.account.avatarTag == null
                                ? null
                                : images.userAvatar(
                                    userId: session.account.userId,
                                    tag: session.account.avatarTag,
                                    logicalWidth: 36,
                                    devicePixelRatio: dpr),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: switch (views) {
                AsyncData(:final value) when value.isEmpty => _Message(gutter: gutter, text: 'Aucune bibliothèque.'),
                AsyncData(:final value) => MediaRow(
                    title: 'Mes bibliothèques',
                    itemCount: value.length,
                    itemExtent: cardWidth + OFSpacing.md,
                    height: cardWidth * 9 / 16 + 28,
                    itemBuilder: (context, i) {
                      final v = value[i];
                      final tag = v.imageTags?['Primary'];
                      return LandscapeCard(
                        width: cardWidth,
                        data: MediaCardData(
                          id: v.id,
                          title: v.name ?? '',
                          imageUrl: tag == null
                              ? null
                              : images.item(
                                  itemId: v.id,
                                  type: JellyfinImageType.primary,
                                  tag: tag,
                                  logicalWidth: cardWidth,
                                  devicePixelRatio: dpr),
                          blurHash: tag == null ? null : v.imageBlurHashes?.primary?[tag],
                        ),
                        onTap: () {},
                      );
                    },
                  ),
                AsyncError(:final error) => _Message(
                    gutter: gutter,
                    text: error is ApiFailure ? error.userMessage : 'Impossible de charger les bibliothèques.',
                    onRetry: () => ref.invalidate(userViewsProvider),
                  ),
                _ => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.gutter, required this.text, this.onRetry});

  final double gutter;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter, vertical: OFSpacing.xxl),
      child: Column(
        children: [
          Text(text, textAlign: TextAlign.center, style: OFTypography.body.copyWith(color: OFColors.textSecondary)),
          if (onRetry != null) ...[
            const SizedBox(height: OFSpacing.lg),
            OFButton.secondary(label: 'Réessayer', onPressed: onRetry),
          ],
        ],
      ),
    );
  }
}

/// Sélecteur de comptes : bascule rapide, ajout, déconnexion.
class AccountSwitcherSheet extends ConsumerWidget {
  const AccountSwitcherSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(sessionControllerProvider);
    final accounts = ref.watch(savedAccountsProvider).value ?? const <StoredAccount>[];
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(OFSpacing.lg, OFSpacing.sm, OFSpacing.lg, OFSpacing.xl),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: OFSpacing.sm, vertical: OFSpacing.sm),
          child: Text('Comptes', style: OFTypography.title2),
        ),
        for (final s in accounts)
          ListTile(
            shape: const RoundedRectangleBorder(borderRadius: OFRadius.mdAll),
            leading: AvatarChip(
              name: s.account.userName,
              imageUrl: s.account.avatarTag == null
                  ? null
                  : JellyfinImageUrlBuilder(s.server.baseUrl).userAvatar(
                      userId: s.account.userId, tag: s.account.avatarTag, logicalWidth: 40, devicePixelRatio: dpr),
            ),
            title: Text(s.account.userName, style: OFTypography.headline),
            subtitle: Text(s.server.name, style: OFTypography.caption.copyWith(color: OFColors.textSecondary)),
            trailing: s.account.id == current?.account.id
                ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary)
                : null,
            onTap: () async {
              Navigator.of(context).pop();
              if (s.account.id == current?.account.id) return;
              final ok = await ref.read(sessionControllerProvider.notifier).switchTo(s.account.id);
              if (!ok && context.mounted) context.go(Routes.connect);
            },
          ),
        const Divider(height: OFSpacing.xl),
        ListTile(
          leading: const Icon(Icons.person_add_alt_rounded, color: OFColors.textPrimary),
          title: const Text('Ajouter un compte', style: OFTypography.headline),
          onTap: () {
            Navigator.of(context).pop();
            context.push(Routes.connect);
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout_rounded, color: OFColors.danger),
          title: Text('Se déconnecter', style: OFTypography.headline.copyWith(color: OFColors.danger)),
          onTap: () async {
            Navigator.of(context).pop();
            await ref.read(sessionControllerProvider.notifier).signOut();
          },
        ),
      ],
    );
  }
}
