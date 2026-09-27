import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/providers.dart';
import '../../auth/presentation/account_switcher.dart';
import '../../home/presentation/home_providers.dart';
import '../../player/domain/playback_engine.dart';
import '../domain/app_settings.dart';
import 'settings_providers.dart';

/// Paramètres : lecture, langues, sous-titres, stockage, compte, debug.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final session = ref.watch(sessionControllerProvider);
    final controller = ref.read(settingsProvider.notifier);
    final identity = ref.watch(clientIdentityProvider);

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
                trailing: e.key == current ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary) : null,
                onTap: () => Navigator.of(context).pop(e.key),
              ),
          ],
        ),
      );
      if (chosen != null) onSelected(chosen);
    }

    // Clé sentinelle pour « choix du serveur » (null ne passe pas par pop()).
    const serverDefault = '';
    final languages = {serverDefault: 'Choix du serveur', ...preferredLanguages};

    return Scaffold(
      appBar: AppBar(
        backgroundColor: OFColors.background,
        leading: IconButton(
          tooltip: 'Retour',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Paramètres', style: OFTypography.headline),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: OFSpacing.xxxl),
        children: [
          const _Section('Lecture'),
          _Tile(
            icon: Icons.wifi_rounded,
            title: 'Qualité maximale en Wi-Fi',
            value: bitrateChoices[settings.maxBitrateWifi] ?? '${settings.maxBitrateWifi}',
            onTap: () => pick<int>(
              title: 'Qualité maximale en Wi-Fi',
              options: bitrateChoices,
              current: settings.maxBitrateWifi,
              onSelected: (v) => controller.update((s) => s.copyWith(maxBitrateWifi: v)),
            ),
          ),
          _Tile(
            icon: Icons.signal_cellular_alt_rounded,
            title: 'Qualité maximale en cellulaire',
            value: bitrateChoices[settings.maxBitrateCellular] ?? '${settings.maxBitrateCellular}',
            onTap: () => pick<int>(
              title: 'Qualité maximale en cellulaire',
              options: bitrateChoices,
              current: settings.maxBitrateCellular,
              onSelected: (v) => controller.update((s) => s.copyWith(maxBitrateCellular: v)),
            ),
          ),
          const _Section('Langues'),
          _Tile(
            icon: Icons.record_voice_over_outlined,
            title: 'Langue audio préférée',
            value: languages[settings.audioLanguage ?? serverDefault]!,
            onTap: () => pick<String>(
              title: 'Langue audio préférée',
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
              title: 'Sous-titres au démarrage',
              options: {for (final m in SubtitleMode.values) m: m.label},
              current: settings.subtitleMode,
              onSelected: (v) => controller.update((s) => s.copyWith(subtitleMode: v)),
            ),
          ),
          _Tile(
            icon: Icons.translate_rounded,
            title: 'Langue des sous-titres',
            value: languages[settings.subtitleLanguage ?? serverDefault]!,
            onTap: () => pick<String>(
              title: 'Langue des sous-titres',
              options: languages,
              current: settings.subtitleLanguage ?? serverDefault,
              onSelected: (v) => controller.update((s) => s.copyWith(subtitleLanguage: () => v.isEmpty ? null : v)),
            ),
          ),
          const _Section('Apparence des sous-titres'),
          _Tile(
            icon: Icons.format_size_rounded,
            title: 'Taille',
            value: _scaleLabel(settings.subtitleScale),
            onTap: () => pick<double>(
              title: 'Taille des sous-titres',
              options: {for (final v in const [0.8, 1.0, 1.25, 1.5]) v: _scaleLabel(v)},
              current: settings.subtitleScale,
              onSelected: (v) => controller.update((s) => s.copyWith(subtitleScale: v)),
            ),
          ),
          _Tile(
            icon: Icons.format_color_fill_rounded,
            title: 'Fond',
            value: _backgroundLabel(settings.subtitleBackground),
            onTap: () => pick<SubtitleBackground>(
              title: 'Fond des sous-titres',
              options: {for (final b in SubtitleBackground.values) b: _backgroundLabel(b)},
              current: settings.subtitleBackground,
              onSelected: (v) => controller.update((s) => s.copyWith(subtitleBackground: v)),
            ),
          ),
          const _Section('Stockage'),
          _Tile(
            icon: Icons.image_outlined,
            title: 'Vider le cache des images',
            onTap: () async {
              await DefaultCacheManager().emptyCache();
              PaintingBinding.instance.imageCache.clear();
              ref.invalidate(homeProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache des images vidé.')));
              }
            },
          ),
          const _Section('Compte'),
          if (session != null)
            _Tile(
              icon: Icons.person_outline_rounded,
              title: session.account.userName,
              value: '${session.server.name} · Jellyfin ${session.server.version}',
              onTap: () => showOFSheet<void>(context, builder: (_) => const AccountSwitcherSheet()),
            ),
          const _Section('Avancé'),
          SwitchListTile(
            secondary: const Icon(Icons.bug_report_outlined, color: OFColors.textSecondary),
            title: const Text('Mode debug', style: OFTypography.body),
            subtitle: Text(
              'Journaux détaillés (requêtes, lecteur, mpv) et infos techniques dans le lecteur.',
              style: OFTypography.caption.copyWith(color: OFColors.textTertiary),
            ),
            value: settings.debugMode,
            onChanged: (v) => controller.update((s) => s.copyWith(debugMode: v)),
          ),
          _Tile(
            icon: Icons.receipt_long_outlined,
            title: 'Journaux',
            value: 'Afficher, copier, effacer',
            onTap: () => context.push(Routes.logs),
          ),
          const _Section('À propos'),
          _Tile(icon: Icons.info_outline_rounded, title: 'OptiFin', value: 'Version ${identity.version}'),
          _Tile(
            icon: Icons.description_outlined,
            title: 'Licences',
            onTap: () => showLicensePage(context: context, applicationName: 'OptiFin', applicationVersion: identity.version),
          ),
        ],
      ),
    );
  }

  static String _scaleLabel(double v) => switch (v) {
        0.8 => 'Petite',
        1.0 => 'Normale',
        1.25 => 'Grande',
        _ => 'Très grande',
      };

  static String _backgroundLabel(SubtitleBackground b) => switch (b) {
        SubtitleBackground.none => 'Contour',
        SubtitleBackground.shadow => 'Ombre',
        SubtitleBackground.box => 'Bandeau',
      };
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(OFSpacing.xl, OFSpacing.xl, OFSpacing.xl, OFSpacing.sm),
        child: Text(title.toUpperCase(), style: OFTypography.caption.copyWith(color: OFColors.textTertiary, letterSpacing: 1.2)),
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

