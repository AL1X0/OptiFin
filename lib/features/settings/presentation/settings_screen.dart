import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/providers.dart';
import '../../auth/presentation/account_switcher.dart';
import '../../home/presentation/home_providers.dart';
import '../../player/domain/engine_selector.dart';
import '../../player/domain/playback_engine.dart';
import '../../player/presentation/playback_providers.dart';
import '../domain/app_settings.dart';
import 'settings_providers.dart';
import '../../../core/l10n/l.dart';

/// Paramètres : lecture, langues, sous-titres, stockage, compte, debug.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final session = ref.watch(sessionControllerProvider);
    final controller = ref.read(settingsProvider.notifier);
    final identity = ref.watch(clientIdentityProvider);
    final device = ref.watch(deviceCapabilitiesProvider).value;

    Future<void> pick<T>({
      required String title,
      required Map<T, String> options,
      required T current,
      required void Function(T) onSelected,
    }) async {
      final chosen = await showOFSheet<T>(
        context,
        builder: (context) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(OFSpacing.lg, 0, OFSpacing.lg, OFSpacing.xl),
          children: [
            Padding(
              padding: const EdgeInsets.all(OFSpacing.sm),
              child: Text(title, style: OFTypography.title2),
            ),
            for (final e in options.entries)
              ListTile(
                shape: const RoundedRectangleBorder(borderRadius: OFRadius.mdAll),
                title: Text(e.value, style: OFTypography.body),
                trailing: e.key == current
                    ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(e.key),
              ),
          ],
        ),
      );
      if (chosen != null) onSelected(chosen);
    }

    // Clé sentinelle pour « choix du serveur » (null ne passe pas par pop()).
    final serverDefault = '';
    final languages = {serverDefault: L.t('Choix du serveur'), ...preferredLanguages};

    return Scaffold(
      appBar: AppBar(
        backgroundColor: OFColors.background,
        leading: IconButton(
          tooltip: L.t('Retour'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(L.t('Paramètres'), style: OFTypography.headline),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: OFSpacing.xxxl),
        children: [
          _Section(L.t('Lecture ').trim()),
          _Tile(
            icon: Icons.wifi_rounded,
            title: L.t('Qualité maximale en Wi-Fi'),
            value: bitrateChoices[settings.maxBitrateWifi] ?? '${settings.maxBitrateWifi}',
            onTap: () => pick<int>(
              title: L.t('Qualité maximale en Wi-Fi'),
              options: bitrateChoices,
              current: settings.maxBitrateWifi,
              onSelected: (v) => controller.update((s) => s.copyWith(maxBitrateWifi: v)),
            ),
          ),
          _Tile(
            icon: Icons.signal_cellular_alt_rounded,
            title: L.t('Qualité maximale en cellulaire'),
            value: bitrateChoices[settings.maxBitrateCellular] ?? '${settings.maxBitrateCellular}',
            onTap: () => pick<int>(
              title: L.t('Qualité maximale en cellulaire'),
              options: bitrateChoices,
              current: settings.maxBitrateCellular,
              onSelected: (v) => controller.update((s) => s.copyWith(maxBitrateCellular: v)),
            ),
          ),
          _Tile(
            icon: Icons.memory_rounded,
            title: L.t('Moteur de lecture'),
            value: switch (settings.enginePreference) {
              EnginePreference.auto => L.t('Automatique (recommandé)'),
              EnginePreference.native => L.t('Natif (AVPlayer / Media3)'),
              EnginePreference.mpv => 'mpv',
            },
            onTap: () => pick<EnginePreference>(
              title: L.t('Moteur de lecture'),
              options: {
                EnginePreference.auto: L.t('Automatique : le meilleur moteur pour chaque fichier'),
                EnginePreference.native: L.t('Natif : HDR, Dolby Vision, économie de batterie'),
                EnginePreference.mpv: L.t('mpv : lit tout, sous-titres ASS fidèles'),
              },
              current: settings.enginePreference,
              onSelected: (v) => controller.update((s) => s.copyWith(enginePreference: v)),
            ),
          ),
          _Tile(
            icon: Icons.closed_caption_outlined,
            title: L.t('Sous-titres image (PGS) sur du HDR'),
            value: switch (settings.imageSubtitles) {
              ImageSubtitlePolicy.auto => L.t('Rendus par mpv'),
              ImageSubtitlePolicy.burnIn => L.t('Incrustés par le serveur'),
            },
            onTap: () => pick<ImageSubtitlePolicy>(
              title: L.t('Sous-titres image sur une vidéo HDR / Dolby Vision'),
              options: {
                ImageSubtitlePolicy.auto: L.t('Rendus par mpv (aucune charge serveur)'),
                ImageSubtitlePolicy.burnIn: L.t('Incrustés par le serveur (garde le lecteur natif)'),
              },
              current: settings.imageSubtitles,
              onSelected: (v) => controller.update((s) => s.copyWith(imageSubtitles: v)),
            ),
          ),
          _Section(L.t('Langues')),
          _Tile(
            icon: Icons.record_voice_over_outlined,
            title: L.t('Langue audio préférée'),
            value: languages[settings.audioLanguage ?? serverDefault]!,
            onTap: () => pick<String>(
              title: L.t('Langue audio préférée'),
              options: languages,
              current: settings.audioLanguage ?? serverDefault,
              onSelected: (v) => controller.update((s) => s.copyWith(audioLanguage: () => v.isEmpty ? null : v)),
            ),
          ),
          _Tile(
            icon: Icons.subtitles_outlined,
            title: 'Sous-titres',
            value: settings.subtitleMode.label,
            onTap: () => pick<SubtitleMode>(
              title: L.t('Sous-titres au démarrage'),
              options: {for (final m in SubtitleMode.values) m: m.label},
              current: settings.subtitleMode,
              onSelected: (v) => controller.update((s) => s.copyWith(subtitleMode: v)),
            ),
          ),
          _Tile(
            icon: Icons.translate_rounded,
            title: L.t('Langue des sous-titres'),
            value: languages[settings.subtitleLanguage ?? serverDefault]!,
            onTap: () => pick<String>(
              title: L.t('Langue des sous-titres'),
              options: languages,
              current: settings.subtitleLanguage ?? serverDefault,
              onSelected: (v) => controller.update((s) => s.copyWith(subtitleLanguage: () => v.isEmpty ? null : v)),
            ),
          ),
          _Section(L.t('Séries')),
          SwitchListTile(
            secondary: const Icon(Icons.fast_forward_outlined, color: OFColors.textSecondary),
            title: Text(L.t('Passer les intros automatiquement'), style: OFTypography.body),
            subtitle: Text(
              L.t('Intros, récapitulatifs et aperçus détectés par le serveur (sinon, un bouton « Passer »).'),
              style: OFTypography.caption.copyWith(color: OFColors.textTertiary),
            ),
            value: settings.autoSkipSegments,
            onChanged: (v) => controller.update((s) => s.copyWith(autoSkipSegments: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.skip_next_outlined, color: OFColors.textSecondary),
            title: Text(L.t('Épisode suivant automatique'), style: OFTypography.body),
            subtitle: Text(
              L.t('Enchaîne après un compte à rebours de 10 s pendant le générique.'),
              style: OFTypography.caption.copyWith(color: OFColors.textTertiary),
            ),
            value: settings.autoPlayNext,
            onChanged: (v) => controller.update((s) => s.copyWith(autoPlayNext: v)),
          ),
          _Section(L.t('Apparence des sous-titres')),
          _Tile(
            icon: Icons.format_size_rounded,
            title: L.t('Taille'),
            value: _scaleLabel(settings.subtitleScale),
            onTap: () => pick<double>(
              title: L.t('Taille des sous-titres'),
              options: {
                for (final v in const [0.8, 1.0, 1.25, 1.5]) v: _scaleLabel(v),
              },
              current: settings.subtitleScale,
              onSelected: (v) => controller.update((s) => s.copyWith(subtitleScale: v)),
            ),
          ),
          _Tile(
            icon: Icons.format_color_fill_rounded,
            title: L.t('Fond'),
            value: _backgroundLabel(settings.subtitleBackground),
            onTap: () => pick<SubtitleBackground>(
              title: L.t('Fond des sous-titres'),
              options: {for (final b in SubtitleBackground.values) b: _backgroundLabel(b)},
              current: settings.subtitleBackground,
              onSelected: (v) => controller.update((s) => s.copyWith(subtitleBackground: v)),
            ),
          ),
          _Section(L.t('Stockage')),
          SwitchListTile(
            secondary: const Icon(Icons.wifi_rounded, color: OFColors.textSecondary),
            title: Text(L.t('Télécharger en Wi-Fi uniquement'), style: OFTypography.body),
            subtitle: Text(
              L.t('Les films et épisodes téléchargés attendent le Wi-Fi (pas de données mobiles).'),
              style: OFTypography.caption.copyWith(color: OFColors.textTertiary),
            ),
            value: settings.downloadWifiOnly,
            onChanged: (v) => controller.update((s) => s.copyWith(downloadWifiOnly: v)),
          ),
          _Tile(
            icon: Icons.image_outlined,
            title: L.t('Vider le cache des images'),
            onTap: () async {
              await DefaultCacheManager().emptyCache();
              PaintingBinding.instance.imageCache.clear();
              ref.invalidate(homeProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L.t('Cache des images vidé.'))));
              }
            },
          ),
          _Section(L.t('Compte')),
          if (session != null)
            _Tile(
              icon: Icons.person_outline_rounded,
              title: session.account.userName,
              value: '${session.server.name} · Jellyfin ${session.server.version}',
              onTap: () => showOFSheet<void>(context, builder: (_) => const AccountSwitcherSheet()),
            ),
          _Section(L.t('Avancé')),
          SwitchListTile(
            secondary: const Icon(Icons.bug_report_outlined, color: OFColors.textSecondary),
            title: Text(L.t('Mode debug'), style: OFTypography.body),
            subtitle: Text(
              L.t('Journaux détaillés (requêtes, lecteur, mpv) et infos techniques dans le lecteur.'),
              style: OFTypography.caption.copyWith(color: OFColors.textTertiary),
            ),
            value: settings.debugMode,
            onChanged: (v) => controller.update((s) => s.copyWith(debugMode: v)),
          ),
          _Tile(
            icon: Icons.receipt_long_outlined,
            title: L.t('Journaux'),
            value: L.t('Afficher, copier, effacer'),
            onTap: () => context.push(Routes.logs),
          ),
          if (device != null)
            _Tile(icon: Icons.developer_board_rounded, title: L.t('Capacités de l’appareil'), value: device.summary),
          _Section(L.t('À propos')),
          _Tile(icon: Icons.info_outline_rounded, title: 'OptiFin', value: L.f('Version {0}', [identity.version])),
          _Tile(
            icon: Icons.description_outlined,
            title: L.t('Licences'),
            onTap: () =>
                showLicensePage(context: context, applicationName: 'OptiFin', applicationVersion: identity.version),
          ),
        ],
      ),
    );
  }

  static String _scaleLabel(double v) => switch (v) {
    0.8 => L.t('Petite'),
    1.0 => L.t('Normale'),
    1.25 => L.t('Grande'),
    _ => L.t('Très grande'),
  };

  static String _backgroundLabel(SubtitleBackground b) => switch (b) {
    SubtitleBackground.none => L.t('Contour'),
    SubtitleBackground.shadow => L.t('Ombre'),
    SubtitleBackground.box => L.t('Bandeau'),
  };
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(OFSpacing.xl, OFSpacing.xl, OFSpacing.xl, OFSpacing.sm),
    child: Text(
      title.toUpperCase(),
      style: OFTypography.caption.copyWith(color: OFColors.textTertiary, letterSpacing: 1.2),
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, this.value, this.onTap});

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: OFColors.textSecondary),
    title: Text(title, style: OFTypography.body),
    subtitle: value == null ? null : Text(value!, style: OFTypography.caption.copyWith(color: OFColors.textTertiary)),
    trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded, color: OFColors.textTertiary),
    onTap: onTap,
  );
}
