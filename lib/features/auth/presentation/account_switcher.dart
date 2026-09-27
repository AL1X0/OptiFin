import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/network/image_url.dart';
import '../../../core/providers.dart';
import '../data/account_store.dart';

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
          leading: const Icon(Icons.settings_outlined, color: OFColors.textPrimary),
          title: const Text('Paramètres', style: OFTypography.headline),
          onTap: () {
            Navigator.of(context).pop();
            context.push(Routes.settings);
          },
        ),
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

/// Avatar du compte courant ; ouvre le sélecteur de comptes.
class AccountButton extends ConsumerWidget {
  const AccountButton({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session == null) return const SizedBox.shrink();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final images = ref.watch(imageUrlBuilderProvider);
    void open() => showOFSheet<void>(context, builder: (_) => const AccountSwitcherSheet());
    return Semantics(
      button: true,
      label: 'Changer de compte, connecté en tant que ${session.account.userName}',
      excludeSemantics: true,
      onTap: open,
      child: GestureDetector(
        onTap: open,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: OFColors.stroke),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 12)],
          ),
          child: AvatarChip(
            name: session.account.userName,
            size: size,
            imageUrl: session.account.avatarTag == null
                ? null
                : images.userAvatar(
                    userId: session.account.userId,
                    tag: session.account.avatarTag,
                    logicalWidth: size,
                    devicePixelRatio: dpr,
                  ),
          ),
        ),
      ),
    );
  }
}
