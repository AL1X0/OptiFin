import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/image_url.dart';
import '../../../core/providers.dart';
import '../data/account_store.dart';
import 'auth_providers.dart';
import 'tv_auth_layout.dart';

/// Écran d'accueil de connexion : comptes enregistrés, serveurs découverts, saisie manuelle.
class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  final _address = TextEditingController();
  String? _error;
  bool _probing = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _connect(String input) async {
    if (input.trim().isEmpty) {
      setState(() => _error = 'Saisissez l’adresse de votre serveur.');
      return;
    }
    setState(() {
      _probing = true;
      _error = null;
    });
    try {
      final server = await ref.read(authRepositoryProvider).probe(input);
      if (!mounted) return;
      ref.read(pendingServerProvider.notifier).set(server);
      unawaited(context.push(Routes.login));
    } on ApiFailure catch (f) {
      if (mounted) setState(() => _error = f.userMessage);
    } finally {
      if (mounted) setState(() => _probing = false);
    }
  }

  Future<void> _resume(StoredAccount stored) async {
    final ok = await ref.read(sessionControllerProvider.notifier).switchTo(stored.account.id);
    if (!mounted) return;
    if (ok) {
      context.go(Routes.home);
    } else {
      // Token perdu : on repasse par le login de ce serveur, identifiant prérempli.
      ref.read(pendingServerProvider.notifier).set(stored.server);
      unawaited(context.push(Routes.login, extra: stored.account.userName));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gutter = OFSpacing.gutterOf(context);
    final accounts = ref.watch(savedAccountsProvider).value ?? const [];
    final discovered = ref.watch(discoveredServersProvider);
    final canPop = context.canPop();

    if (OFDevice.tv) {
      final servers = discovered.value ?? const [];
      return TvAuthLayout(
        title: 'OptiFin',
        subtitle: 'Connectez-vous à votre serveur Jellyfin.',
        children: [
          if (accounts.isNotEmpty) ...[
            const TvSectionLabel('Comptes'),
            for (final (i, a) in accounts.indexed)
              TvChoiceTile(
                autofocus: i == 0,
                leading: _AccountAvatar(stored: a),
                title: a.account.userName,
                subtitle: a.server.name,
                onSelect: () => _resume(a),
              ),
          ],
          TvSectionLabel(discovered.isLoading ? 'Recherche sur ce réseau…' : 'Sur ce réseau'),
          if (servers.isEmpty && !discovered.isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: OFSpacing.sm),
              child: Text(
                'Aucun serveur détecté automatiquement.',
                style: OFTypography.callout.copyWith(color: OFColors.textTertiary),
              ),
            ),
          for (final (i, server) in servers.indexed)
            TvChoiceTile(
              autofocus: accounts.isEmpty && i == 0,
              leading: const _ServerIcon(),
              title: server.name,
              subtitle: server.address.toString(),
              onSelect: _probing ? null : () => _connect(server.address.toString()),
            ),
          const TvSectionLabel('Adresse du serveur'),
          OFTextField(
            label: 'https://jellyfin.exemple.fr',
            controller: _address,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onSubmitted: _connect,
            errorText: _error,
          ),
          const SizedBox(height: OFSpacing.md),
          OFButton(
            label: 'Continuer',
            expand: true,
            loading: _probing,
            autofocus: accounts.isEmpty && servers.isEmpty,
            onPressed: () => _connect(_address.text),
          ),
          if (canPop) ...[
            const SizedBox(height: OFSpacing.sm),
            OFButton.secondary(label: 'Annuler', expand: true, onPressed: () => context.pop()),
          ],
        ],
      );
    }

    return Scaffold(
      // Arrivée douce du formulaire.
      body: FadeSlideIn(
        offset: 24,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: gutter, vertical: OFSpacing.xxl),
                children: [
                  if (canPop)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OFIconButton(icon: Icons.close_rounded, tooltip: 'Fermer', onPressed: () => context.pop()),
                    ),
                  const SizedBox(height: OFSpacing.xl),
                  Semantics(header: true, child: const Text('OptiFin', style: OFTypography.display)),
                  const SizedBox(height: OFSpacing.sm),
                  Text(
                    'Connectez-vous à votre serveur Jellyfin.',
                    style: OFTypography.body.copyWith(color: OFColors.textSecondary),
                  ),
                  if (accounts.isNotEmpty) ...[
                    const SizedBox(height: OFSpacing.xxl),
                    const _SectionTitle('Comptes'),
                    for (final a in accounts) _AccountTile(stored: a, onTap: () => _resume(a)),
                  ],
                  const SizedBox(height: OFSpacing.xxl),
                  _SectionTitle(
                    'Sur ce réseau',
                    trailing: discovered.isLoading
                        ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                            tooltip: 'Relancer la recherche',
                            icon: const Icon(Icons.refresh_rounded, size: 20, color: OFColors.textSecondary),
                            onPressed: () => ref.invalidate(discoveredServersProvider),
                          ),
                  ),
                  ...switch (discovered) {
                    AsyncData(:final value) when value.isEmpty => [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: OFSpacing.sm),
                        child: Text(
                          'Aucun serveur détecté automatiquement.',
                          style: OFTypography.callout.copyWith(color: OFColors.textTertiary),
                        ),
                      ),
                    ],
                    AsyncValue(:final value?) => [
                      for (final s in value)
                        _ServerTile(
                          name: s.name,
                          address: s.address.toString(),
                          onTap: _probing ? null : () => _connect(s.address.toString()),
                        ),
                    ],
                    _ => const [],
                  },
                  const SizedBox(height: OFSpacing.xxl),
                  const _SectionTitle('Adresse du serveur'),
                  OFTextField(
                    label: 'https://jellyfin.exemple.fr',
                    controller: _address,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    autofillHints: const [AutofillHints.url],
                    onSubmitted: _connect,
                    errorText: _error,
                  ),
                  const SizedBox(height: OFSpacing.lg),
                  OFButton(
                    label: 'Continuer',
                    expand: true,
                    loading: _probing,
                    onPressed: () => _connect(_address.text),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: OFSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text.toUpperCase(),
                style: OFTypography.caption.copyWith(color: OFColors.textTertiary, letterSpacing: 1.2),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({required this.name, required this.address, required this.onTap});

  final String name;
  final String address;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _Tile(leading: const _ServerIcon(), title: name, subtitle: address, onTap: onTap);
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.stored, required this.onTap});

  final StoredAccount stored;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = stored.account;
    return _Tile(
      leading: _AccountAvatar(stored: stored),
      title: a.userName,
      subtitle: stored.server.name,
      onTap: onTap,
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.leading, required this.title, required this.subtitle, required this.onTap});

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: OFSpacing.sm),
      child: Material(
        color: OFColors.surface,
        borderRadius: OFRadius.mdAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(OFSpacing.md),
            child: Row(
              children: [
                leading,
                const SizedBox(width: OFSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: OFTypography.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        subtitle,
                        style: OFTypography.caption.copyWith(color: OFColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: OFColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerIcon extends StatelessWidget {
  const _ServerIcon();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 40,
    child: DecoratedBox(
      decoration: BoxDecoration(color: OFColors.surfaceRaised, shape: BoxShape.circle),
      child: Icon(Icons.dns_rounded, size: 20, color: OFColors.textSecondary),
    ),
  );
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.stored});

  final StoredAccount stored;

  @override
  Widget build(BuildContext context) {
    final a = stored.account;
    final avatar = JellyfinImageUrlBuilder(stored.server.baseUrl).userAvatar(
      userId: a.userId,
      tag: a.avatarTag,
      logicalWidth: 40,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    return AvatarChip(name: a.userName, imageUrl: a.avatarTag == null ? null : avatar);
  }
}
