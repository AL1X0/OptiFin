import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_titles.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/logging/app_log.dart';
import '../../../core/providers.dart';
import '../../../core/l10n/l.dart';

/// Journaux de l'application : lecture, filtre par niveau, copie en un geste.
/// Les secrets sont déjà masqués dans le journal (voir [AppLog.redact]).
class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  LogLevel _minLevel = LogLevel.debug;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    final text = AppLog.instance.export(minLevel: _minLevel);
    await Clipboard.setData(ClipboardData(text: text.isEmpty ? L.t('(journal vide)') : text));
    if (!mounted) return;
    unawaited(HapticFeedback.mediumImpact());
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(L.f('{0} lignes copiées dans le presse-papiers', [text.split('\n').length]))));
  }

  /// Envoie le journal au serveur Jellyfin (Tableau de bord › Journaux, fichier
  /// « upload_… »).
  Future<void> _upload() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await ref
          .read(jellyfinDioProvider)
          .post<Map<String, Object?>>(
            '/ClientLog/Document',
            data: AppLog.instance.export(minLevel: _minLevel),
            options: Options(contentType: 'text/plain'),
          );
      final name = response.data?['FileName'] ?? 'journal';
      messenger.showSnackBar(SnackBar(content: Text(L.f('Envoyé au serveur : {0} (Tableau de bord › Journaux)', [name]))));
    } catch (e) {
      AppLog.w('log', 'Envoi du journal impossible : $e');
      messenger.showSnackBar(
        SnackBar(content: Text(L.t('Envoi impossible (serveur hors ligne ou envoi désactivé).'))),
      );
    }
  }

  Color _color(LogLevel level) => switch (level) {
    LogLevel.error => OFColors.danger,
    LogLevel.warning => OFColors.warning,
    LogLevel.info => OFColors.textPrimary,
    LogLevel.debug => OFColors.textTertiary,
  };

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final top = MediaQuery.paddingOf(context).top;
    final gutter = OFSpacing.gutterOf(context);
    return OFRouteTitle(
      title: L.t('Journaux'),
      child: Scaffold(
        body: Column(
          children: [
            GlassSurface(
              borderRadius: BorderRadius.zero,
              child: ColoredBox(
                color: const Color(0xB3000000),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    gutter - OFSpacing.sm,
                    top + OFSpacing.xs,
                    gutter - OFSpacing.sm,
                    OFSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (context.canPop())
                            OFBackButton(
                              previousTitle: OFRouteTitles.previousOf(context),
                              onPressed: () => context.pop(),
                            ),
                          const Spacer(),
                          OFIconButton(
                            tooltip: L.t('Envoyer au serveur'),
                            icon: Icons.cloud_upload_outlined,
                            onPressed: _upload,
                          ),
                          const SizedBox(width: OFSpacing.xs),
                          OFIconButton(tooltip: L.t('Tout copier'), icon: Icons.copy_all_rounded, onPressed: _copy),
                          const SizedBox(width: OFSpacing.xs),
                          OFIconButton(
                            tooltip: L.t('Effacer'),
                            icon: Icons.delete_sweep_outlined,
                            onPressed: AppLog.instance.clear,
                          ),
                        ],
                      ),
                      const SizedBox(height: OFSpacing.xs),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: OFSpacing.sm),
                        child: Semantics(
                          header: true,
                          child: Text(
                            L.t('Journaux'),
                            style: OFTypography.title1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: OFSpacing.lg, vertical: OFSpacing.sm),
              children: [
                for (final (level, label) in [
                  (LogLevel.debug, L.t('Tout')),
                  (LogLevel.info, L.t('Infos')),
                  (LogLevel.warning, L.t('Avertissements')),
                  (LogLevel.error, L.t('Erreurs')),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: OFSpacing.sm),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _minLevel == level,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _minLevel = level),
                      labelStyle: OFTypography.caption.copyWith(
                        color: _minLevel == level ? OFColors.background : OFColors.textPrimary,
                      ),
                      selectedColor: accent,
                      backgroundColor: OFColors.surfaceRaised,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: AppLog.instance,
              builder: (context, _) {
                final entries = AppLog.instance.entries.where((e) => e.level.index >= _minLevel.index).toList();
                if (entries.isEmpty) {
                  return Center(
                    child: Text(
                      AppLog.instance.verbose
                          ? L.t('Journal vide.')
                          : L.t('Journal vide. Activez le mode debug pour plus de détails.'),
                      style: OFTypography.callout.copyWith(color: OFColors.textTertiary),
                    ),
                  );
                }
                // Liste inversée : les dernières lignes en bas, visibles d'emblée.
                return SelectionArea(
                  child: ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(OFSpacing.lg, OFSpacing.sm, OFSpacing.lg, OFSpacing.xxl),
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final e = entries[entries.length - 1 - i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          e.format(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            height: 1.35,
                            color: _color(e.level),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _copy,
        backgroundColor: OFColors.textPrimary,
        foregroundColor: OFColors.background,
        icon: const Icon(Icons.copy_rounded),
        label: Text(L.t('Copier')),
      ),
      ),
    );
  }
}
