import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/image_url.dart';
import '../../../core/providers.dart';
import '../data/auth_repository.dart';
import '../domain/entities.dart';
import 'auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.initialUsername});

  final String? initialUsername;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final _username = TextEditingController(text: widget.initialUsername);
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _finish(ActiveSession session) async {
    await ref.read(sessionControllerProvider.notifier).signIn(session);
    TextInput.finishAutofillContext();
    if (mounted) context.go(Routes.home);
  }

  Future<void> _login(JellyfinServer server) async {
    if (_username.text.trim().isEmpty) {
      setState(() => _error = 'Saisissez votre nom d’utilisateur.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await ref
          .read(authRepositoryProvider)
          .login(server, username: _username.text.trim(), password: _password.text);
      await _finish(session);
    } on ApiFailure catch (f) {
      if (mounted) setState(() => _error = f.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _quickConnect(JellyfinServer server) async {
    final session = await showOFSheet<ActiveSession>(context, builder: (_) => _QuickConnectSheet(server: server));
    if (session != null) await _finish(session);
  }

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(pendingServerProvider);
    if (server == null) {
      // Arrivée directe (ex. restauration d'état) : retour au choix du serveur.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Routes.connect);
      });
      return const Scaffold();
    }

    final users = ref.watch(publicUsersProvider(server)).value ?? const [];
    final quickConnect = ref.watch(quickConnectEnabledProvider(server)).value ?? false;
    final gutter = OFSpacing.screenGutter(MediaQuery.sizeOf(context).width);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final images = JellyfinImageUrlBuilder(server.baseUrl);

    return Scaffold(
      // Arrivée douce du formulaire.
      body: FadeSlideIn(
        offset: 24,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AutofillGroup(
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: gutter, vertical: OFSpacing.xxl),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OFIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Retour',
                        onPressed: () => context.pop(),
                      ),
                    ),
                    const SizedBox(height: OFSpacing.xl),
                    Semantics(header: true, child: Text(server.name, style: OFTypography.title1)),
                    const SizedBox(height: OFSpacing.xs),
                    Text(
                      '${server.baseUrl} · Jellyfin ${server.version}',
                      style: OFTypography.caption.copyWith(color: OFColors.textTertiary),
                    ),
                    if (users.isNotEmpty) ...[
                      const SizedBox(height: OFSpacing.xl),
                      SizedBox(
                        height: 96,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: users.length,
                          separatorBuilder: (_, _) => const SizedBox(width: OFSpacing.lg),
                          itemBuilder: (context, i) {
                            final u = users[i];
                            final selected = _username.text == u.name;
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _username.text = u.name);
                              },
                              child: Column(
                                children: [
                                  AnimatedContainer(
                                    duration: OFMotion.of(context).fast,
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: AvatarChip(
                                      name: u.name,
                                      size: 60,
                                      imageUrl: u.avatarTag == null
                                          ? null
                                          : images.userAvatar(
                                              userId: u.id,
                                              tag: u.avatarTag,
                                              logicalWidth: 60,
                                              devicePixelRatio: dpr,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: OFSpacing.xs),
                                  SizedBox(
                                    width: 72,
                                    child: Text(
                                      u.name,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: OFTypography.caption,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: OFSpacing.xl),
                    OFTextField(
                      label: 'Nom d’utilisateur',
                      controller: _username,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                    ),
                    const SizedBox(height: OFSpacing.md),
                    OFTextField(
                      label: 'Mot de passe',
                      controller: _password,
                      obscure: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _login(server),
                      errorText: _error,
                    ),
                    const SizedBox(height: OFSpacing.xl),
                    OFButton(label: 'Se connecter', expand: true, loading: _busy, onPressed: () => _login(server)),
                    if (quickConnect) ...[
                      const SizedBox(height: OFSpacing.md),
                      OFButton.secondary(
                        label: 'Utiliser Quick Connect',
                        icon: Icons.bolt_rounded,
                        expand: true,
                        onPressed: _busy ? null : () => _quickConnect(server),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Affiche le code Quick Connect et attend l'autorisation depuis un autre appareil.
class _QuickConnectSheet extends ConsumerStatefulWidget {
  const _QuickConnectSheet({required this.server});

  final JellyfinServer server;

  @override
  ConsumerState<_QuickConnectSheet> createState() => _QuickConnectSheetState();
}

class _QuickConnectSheetState extends ConsumerState<_QuickConnectSheet> {
  QuickConnectTicket? _ticket;
  String? _error;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  Future<void> _start() async {
    final repo = ref.read(authRepositoryProvider);
    try {
      final ticket = await repo.initiateQuickConnect(widget.server);
      if (_cancelled) return;
      setState(() => _ticket = ticket);
      final session = await repo.awaitQuickConnect(widget.server, ticket);
      if (!_cancelled && mounted) Navigator.of(context).pop(session);
    } on ApiFailure catch (f) {
      if (!_cancelled && mounted) setState(() => _error = f.userMessage);
    } on StateError {
      if (!_cancelled && mounted) setState(() => _error = 'Le code a expiré. Réessayez.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;
    return Padding(
      padding: const EdgeInsets.fromLTRB(OFSpacing.xl, OFSpacing.lg, OFSpacing.xl, OFSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Quick Connect', style: OFTypography.title2),
          const SizedBox(height: OFSpacing.sm),
          Text(
            'Sur un appareil déjà connecté, ouvrez Jellyfin › Profil › Quick Connect et saisissez ce code.',
            textAlign: TextAlign.center,
            style: OFTypography.callout.copyWith(color: OFColors.textSecondary),
          ),
          const SizedBox(height: OFSpacing.xl),
          if (_error != null)
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: OFTypography.callout.copyWith(color: OFColors.danger),
            )
          else if (ticket == null)
            const SizedBox(height: 56, child: Center(child: OFLoader()))
          else ...[
            Semantics(
              label: 'Code ${ticket.code.split('').join(' ')}',
              excludeSemantics: true,
              child: SelectableText(
                ticket.code,
                style: OFTypography.display.copyWith(
                  fontSize: 44,
                  letterSpacing: 8,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: OFSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: OFSpacing.sm),
                Text('En attente d’autorisation…', style: OFTypography.caption.copyWith(color: OFColors.textTertiary)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
