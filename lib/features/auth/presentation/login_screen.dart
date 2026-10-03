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
import 'tv_auth_layout.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.initialUsername});

  final String? initialUsername;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final _username = TextEditingController(text: widget.initialUsername);
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
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
    // TV : fenêtre centrée (un panneau venu du bas n'a pas de sens sur un téléviseur).
    final session = OFDevice.tv
        ? await showDialog<ActiveSession>(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: OFColors.surface,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
              child: SizedBox(width: 560, child: _QuickConnectSheet(server: server)),
            ),
          )
        : await showOFSheet<ActiveSession>(context, builder: (_) => _QuickConnectSheet(server: server));
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
    final gutter = OFSpacing.gutterOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final images = JellyfinImageUrlBuilder(server.baseUrl);

    if (OFDevice.tv) {
      return TvAuthLayout(
        title: server.name,
        subtitle: quickConnect ? 'Le plus simple : Quick Connect.' : 'Qui regarde ?',
        footer: '${server.baseUrl} · Jellyfin ${server.version}',
        children: [
          if (quickConnect) ...[
            OFButton(
              label: 'Se connecter avec Quick Connect',
              icon: Icons.bolt_rounded,
              expand: true,
              autofocus: true,
              onPressed: _busy ? null : () => _quickConnect(server),
            ),
            const SizedBox(height: OFSpacing.xs),
            Text(
              'Un code s’affiche : validez-le depuis Jellyfin sur votre téléphone.',
              style: OFTypography.caption.copyWith(color: OFColors.textTertiary),
            ),
            const TvSectionLabel('Ou avec un mot de passe'),
          ],
          if (users.isNotEmpty) ...[
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                padding: const EdgeInsets.symmetric(vertical: OFSpacing.xs),
                itemCount: users.length,
                separatorBuilder: (_, _) => const SizedBox(width: OFSpacing.lg),
                itemBuilder: (context, i) {
                  final u = users[i];
                  final selected = _username.text == u.name;
                  return TvFocusable(
                    autofocus: !quickConnect && i == 0,
                    borderRadius: const BorderRadius.all(Radius.circular(40)),
                    scale: 1.1,
                    ring: false,
                    onSelect: () {
                      setState(() => _username.text = u.name);
                      // Utilisateur choisi : on passe au mot de passe.
                      _passwordFocus.requestFocus();
                    },
                    child: _TvUser(
                      name: u.name,
                      selected: selected,
                      imageUrl: u.avatarTag == null
                          ? null
                          : images.userAvatar(userId: u.id, tag: u.avatarTag, logicalWidth: 64, devicePixelRatio: dpr),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: OFSpacing.sm),
          ],
          OFTextField(label: 'Nom d’utilisateur', controller: _username, textInputAction: TextInputAction.next),
          const SizedBox(height: OFSpacing.sm),
          OFTextField(
            label: 'Mot de passe',
            controller: _password,
            focusNode: _passwordFocus,
            obscure: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _login(server),
            errorText: _error,
          ),
          const SizedBox(height: OFSpacing.md),
          OFButton(label: 'Se connecter', expand: true, loading: _busy, onPressed: () => _login(server)),
          const SizedBox(height: OFSpacing.sm),
          OFButton.secondary(label: 'Changer de serveur', expand: true, onPressed: () => context.pop()),
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
                            void pick() {
                              HapticFeedback.selectionClick();
                              setState(() => _username.text = u.name);
                            }

                            return TvFocusable(
                              onSelect: pick,
                              borderRadius: const BorderRadius.all(Radius.circular(OFRadius.md)),
                              child: GestureDetector(
                                onTap: pick,
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

/// Profil sur l'écran de connexion TV : avatar entouré de blanc au focus, liseré coloré
/// pour le profil choisi.
class _TvUser extends StatelessWidget {
  const _TvUser({required this.name, required this.selected, this.imageUrl});

  final String name;
  final bool selected;
  final Uri? imageUrl;

  @override
  Widget build(BuildContext context) {
    final focused = Focus.of(context).hasPrimaryFocus || (Focus.maybeOf(context)?.hasFocus ?? false);
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: OFMotion.of(context).fast,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: focused ? OFColors.textPrimary : (selected ? accent : Colors.transparent),
              width: 3,
            ),
          ),
          child: AvatarChip(name: name, size: 64, imageUrl: imageUrl),
        ),
        const SizedBox(height: OFSpacing.xs),
        SizedBox(
          width: 84,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OFTypography.caption.copyWith(color: focused ? OFColors.textPrimary : OFColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
