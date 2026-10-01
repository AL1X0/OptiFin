import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/providers.dart';
import '../domain/syncplay_models.dart';
import 'watch_party_controller.dart';

/// Ouvre le panneau « Soirée » (feuille sur mobile et tablette, dialogue sur TV).
void showWatchParty(BuildContext context) {
  if (OFDevice.tv) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const Dialog(
          backgroundColor: OFColors.surfaceRaised,
          shape: RoundedRectangleBorder(borderRadius: OFRadius.lgAll),
          child: SizedBox(width: 520, child: WatchPartySheet()),
        ),
      ),
    );
    return;
  }
  unawaited(
    showOFSheet<void>(context, builder: (_) => const WatchPartySheet()),
  );
}

/// Bouton « Soirée » de l'accueil : anneau d'accent et nombre de participants en soirée.
class WatchPartyButton extends ConsumerWidget {
  const WatchPartyButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final party = ref.watch(watchPartyProvider);
    if (!party.available) return const SizedBox.shrink();
    final group = party.group;
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      label: group == null
          ? 'Soirée : regarder ensemble'
          : 'Soirée ${group.name}, ${group.participants.length} participants',
      excludeSemantics: true,
      child: TvFocusable(
        onSelect: () => showWatchParty(context),
        scale: 1.1,
        child: GestureDetector(
          onTap: () => showWatchParty(context),
          child: GlassSurface(
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(18)),
                border: Border.all(
                  color: group == null ? OFColors.stroke : accent,
                  width: group == null ? 1 : 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.groups_rounded,
                    size: 18,
                    color: group == null ? OFColors.textPrimary : accent,
                  ),
                  if (group != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '${group.participants.length}',
                      style: OFTypography.callout.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Panneau « Soirée » : créer une soirée ou en rejoindre une ; une fois dedans, participants, état
/// et sortie. Tout titre lancé démarre alors chez tout le monde, au même moment.
class WatchPartySheet extends ConsumerStatefulWidget {
  const WatchPartySheet({super.key});

  @override
  ConsumerState<WatchPartySheet> createState() => _WatchPartySheetState();
}

class _WatchPartySheetState extends ConsumerState<WatchPartySheet> {
  late final TextEditingController _name;
  Future<List<GroupInfo>>? _groups;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionControllerProvider)?.account.userName ?? '';
    _name = TextEditingController(text: 'Soirée de $user');
    _refresh();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _refresh() => _groups = ref
      .read(watchPartyProvider.notifier)
      .list()
      .catchError((Object _) => <GroupInfo>[]);

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    await action();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final party = ref.watch(watchPartyProvider);
    final controller = ref.read(watchPartyProvider.notifier);
    final group = party.group;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        OFSpacing.xl,
        OFSpacing.lg,
        OFSpacing.xl,
        OFSpacing.xl,
      ),
      children: [
        const Text('Soirée', style: OFTypography.title2),
        const SizedBox(height: OFSpacing.sm),
        if (group != null) ...[
          Text(group.name, style: OFTypography.headline),
          const SizedBox(height: OFSpacing.xs),
          Text(
            switch (group.state) {
              GroupState.playing => 'Lecture en cours',
              GroupState.paused => 'En pause',
              GroupState.waiting => 'En attente des participants…',
              GroupState.idle => 'Lancez un film ou un épisode : il démarre chez tout le monde, au même moment.',
            },
            style: OFTypography.caption.copyWith(color: OFColors.textSecondary),
          ),
          if (!party.connected) ...[
            const SizedBox(height: OFSpacing.xs),
            Text(
              'Connexion au serveur interrompue, reconnexion…',
              style: OFTypography.caption.copyWith(color: OFColors.danger),
            ),
          ],
          const SizedBox(height: OFSpacing.lg),
          Text(
            'PARTICIPANTS (${group.participants.length})',
            style: OFTypography.caption.copyWith(color: OFColors.textTertiary),
          ),
          const SizedBox(height: OFSpacing.sm),
          for (final name in group.participants)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: OFSpacing.xs),
              child: Row(
                children: [
                  AvatarChip(name: name, size: 32),
                  const SizedBox(width: OFSpacing.md),
                  Text(name, style: OFTypography.body),
                ],
              ),
            ),
          const SizedBox(height: OFSpacing.lg),
          OFButton.secondary(
            label: 'Quitter la soirée',
            icon: Icons.logout_rounded,
            expand: true,
            autofocus: OFDevice.tv,
            loading: _busy,
            onPressed: () => _run(controller.leave),
          ),
        ] else ...[
          Text(
            'Regardez un film à plusieurs, chacun chez soi : lecture, pause et avance sont synchronisées.',
            style: OFTypography.caption.copyWith(color: OFColors.textSecondary),
          ),
          const SizedBox(height: OFSpacing.lg),
          // TV : nom par défaut (saisir au clavier de la télécommande est pénible).
          if (!OFDevice.tv) ...[
            OFTextField(
              label: 'Nom de la soirée',
              controller: _name,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: OFSpacing.md),
          ],
          OFButton(
            label: 'Créer une soirée',
            icon: Icons.add_rounded,
            expand: true,
            autofocus: OFDevice.tv,
            loading: _busy,
            onPressed: party.connected
                ? () => _run(
                    () => controller.create(
                      _name.text.trim().isEmpty ? 'Soirée' : _name.text.trim(),
                    ),
                  )
                : null,
          ),
          if (!party.connected) ...[
            const SizedBox(height: OFSpacing.xs),
            Text(
              'Connexion au serveur en cours…',
              style: OFTypography.caption.copyWith(
                color: OFColors.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: OFSpacing.xl),
          Row(
            children: [
              Expanded(
                child: Text(
                  'SOIRÉES EN COURS',
                  style: OFTypography.caption.copyWith(
                    color: OFColors.textTertiary,
                  ),
                ),
              ),
              OFIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Actualiser',
                onPressed: () => setState(_refresh),
              ),
            ],
          ),
          const SizedBox(height: OFSpacing.sm),
          FutureBuilder<List<GroupInfo>>(
            future: _groups,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(OFSpacing.md),
                  child: OFLoader(size: 22),
                );
              }
              final groups = snapshot.data ?? const <GroupInfo>[];
              if (groups.isEmpty) {
                return Text(
                  'Aucune soirée pour le moment.',
                  style: OFTypography.caption.copyWith(
                    color: OFColors.textSecondary,
                  ),
                );
              }
              return Column(
                children: [
                  for (final g in groups)
                    Container(
                      margin: const EdgeInsets.only(bottom: OFSpacing.sm),
                      padding: const EdgeInsets.fromLTRB(
                        OFSpacing.md,
                        OFSpacing.sm,
                        OFSpacing.sm,
                        OFSpacing.sm,
                      ),
                      decoration: const BoxDecoration(
                        color: OFColors.surface,
                        borderRadius: OFRadius.mdAll,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.name,
                                  style: OFTypography.callout.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  g.participants.join(', '),
                                  style: OFTypography.caption.copyWith(
                                    color: OFColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          OFButton(
                            label: 'Rejoindre',
                            onPressed: _busy
                                ? null
                                : () => _run(() => controller.join(g.id)),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}
