import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../domain/engine_selector.dart';
import '../domain/playback_engine.dart';
import '../domain/playback_plan.dart';
import 'player_controller.dart';

/// Feuille « Audio et sous-titres » : pistes, vitesse, taille des sous-titres.
class TracksSheet extends ConsumerWidget {
  const TracksSheet({super.key, required this.controller, required this.engine, this.onSearchSubtitles});

  final PlayerController controller;
  final PlaybackEngine engine;

  /// Ouvre la recherche de sous-titres sur le serveur.
  final VoidCallback? onSearchSubtitles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerControllerProvider(controller.args));
    final plan = state.plan;
    final caps = engine.capabilities;
    final size = MediaQuery.sizeOf(context);
    if (plan == null) return const SizedBox(height: 120);

    Widget tile({required String label, String? detail, required bool selected, required VoidCallback onTap}) =>
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          shape: const RoundedRectangleBorder(borderRadius: OFRadius.mdAll),
          title: Text(label, style: OFTypography.callout, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: detail == null
              ? null
              : Text(detail, style: OFTypography.caption.copyWith(color: OFColors.textTertiary)),
          trailing: selected ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary) : null,
          selected: selected,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
        );

    String? detailFor(MediaTrack t) => [
      if (t.isDefault) 'Par défaut',
      if (t.isForced) 'Forcés',
      if (t.isExternal) 'Externe',
      if (t.type == TrackType.subtitle && t.isBitmap) 'Image',
    ].join(' · ').ifEmptyNull;

    final audio = ListView(
      shrinkWrap: true,
      children: [
        const _Header('Audio'),
        for (final t in plan.audioTracks)
          tile(
            label: t.label,
            detail: detailFor(t),
            selected: t.index == plan.audioIndex,
            onTap: () => controller.selectAudio(t),
          ),
      ],
    );

    final subtitles = ListView(
      shrinkWrap: true,
      children: [
        const _Header('Sous-titres'),
        tile(label: 'Aucun', selected: plan.subtitleIndex == null, onTap: () => controller.selectSubtitle(null)),
        for (final t in plan.subtitleTracks)
          tile(
            label: t.label,
            detail: detailFor(t),
            selected: t.index == plan.subtitleIndex,
            onTap: () => controller.selectSubtitle(t),
          ),
        if (onSearchSubtitles != null)
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            shape: const RoundedRectangleBorder(borderRadius: OFRadius.mdAll),
            leading: const Icon(Icons.search_rounded, color: OFColors.textSecondary),
            title: const Text('Rechercher en ligne…', style: OFTypography.callout),
            onTap: onSearchSubtitles,
          ),
      ],
    );

    final options = ListView(
      shrinkWrap: true,
      children: [
        const _Header('Moteur de lecture'),
        _Chips<EnginePreference>(
          values: EnginePreference.values,
          selected: state.preference ?? EnginePreference.auto,
          label: (v) => switch (v) {
            EnginePreference.auto => 'Auto',
            EnginePreference.native => 'Natif',
            EnginePreference.mpv => 'mpv',
          },
          onSelected: controller.setEnginePreference,
        ),
        if (state.decision != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(OFSpacing.lg, OFSpacing.sm, OFSpacing.lg, 0),
            child: Text(
              '${engine.name} · ${plan.method.label}',
              style: OFTypography.caption.copyWith(color: OFColors.textTertiary),
            ),
          ),
        if (caps.playbackSpeed) ...[
          const _Header('Vitesse'),
          StreamBuilder<PlayerSnapshot>(
            stream: engine.snapshots,
            initialData: engine.snapshot,
            builder: (context, snap) => _Chips<double>(
              values: const [0.75, 1, 1.25, 1.5, 2],
              selected: snap.data?.rate ?? 1,
              label: (v) => '${v.toString().replaceAll('.', ',')}×',
              onSelected: controller.setRate,
            ),
          ),
        ],
        if (caps.subtitleDelay) ...[
          const _Header('Décalage des sous-titres'),
          _DelayStepper(
            value: state.subtitleDelay,
            onChanged: controller.setSubtitleDelay,
            hint: 'Positif : les sous-titres apparaissent plus tard.',
          ),
        ],
        if (caps.audioDelay) ...[
          const _Header('Décalage audio'),
          _DelayStepper(
            value: state.audioDelay,
            onChanged: controller.setAudioDelay,
            hint: 'Positif : le son est retardé.',
          ),
        ],
        if (caps.subtitleStyling) ...[
          const _Header('Taille des sous-titres'),
          _Chips<double>(
            values: const [0.8, 1, 1.25, 1.5],
            selected: state.subtitleStyle.scale,
            label: (v) => switch (v) {
              0.8 => 'Petite',
              1.0 => 'Normale',
              1.25 => 'Grande',
              _ => 'Très grande',
            },
            onSelected: (v) => controller.setSubtitleStyle(state.subtitleStyle.copyWith(scale: v)),
          ),
          const _Header('Fond des sous-titres'),
          _Chips<SubtitleBackground>(
            values: SubtitleBackground.values,
            selected: state.subtitleStyle.background,
            label: (v) => switch (v) {
              SubtitleBackground.none => 'Contour',
              SubtitleBackground.shadow => 'Ombre',
              SubtitleBackground.box => 'Bandeau',
            },
            onSelected: (v) => controller.setSubtitleStyle(state.subtitleStyle.copyWith(background: v)),
          ),
        ],
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: size.height * 0.85),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(OFSpacing.lg, 0, OFSpacing.lg, OFSpacing.lg),
        // Paysage : 3 colonnes côte à côte ; portrait : empilées.
        child: size.width > size.height
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: audio),
                  Expanded(child: subtitles),
                  Expanded(child: options),
                ],
              )
            : ListView(shrinkWrap: true, children: [audio, subtitles, options]),
      ),
    );
  }
}

extension on String {
  String? get ifEmptyNull => isEmpty ? null : this;
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(OFSpacing.lg, OFSpacing.lg, OFSpacing.lg, OFSpacing.sm),
    child: Text(
      text.toUpperCase(),
      style: OFTypography.caption.copyWith(color: OFColors.textTertiary, letterSpacing: 1.2),
    ),
  );
}

class _Chips<T> extends StatelessWidget {
  const _Chips({required this.values, required this.selected, required this.label, required this.onSelected});

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: OFSpacing.lg),
      child: Wrap(
        spacing: OFSpacing.sm,
        runSpacing: OFSpacing.sm,
        children: [
          for (final v in values)
            ChoiceChip(
              label: Text(label(v)),
              selected: v == selected,
              showCheckmark: false,
              onSelected: (_) => onSelected(v),
              labelStyle: OFTypography.callout.copyWith(
                color: v == selected ? OFColors.background : OFColors.textPrimary,
              ),
              selectedColor: accent,
              backgroundColor: OFColors.surfaceRaised,
              side: BorderSide.none,
              shape: const StadiumBorder(),
            ),
        ],
      ),
    );
  }
}

/// Overlay de debug (appui long sur le titre) : moteur, mode, codecs, débit.
class DebugOverlay extends StatelessWidget {
  const DebugOverlay({super.key, required this.ui, required this.engine, required this.snapshot});

  final PlayerUiState ui;
  final PlaybackEngine engine;
  final PlayerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final plan = ui.plan;
    final size = snapshot.videoSize;
    final decision = ui.decision;
    final lines = <(String, String)>[
      ('Moteur', engine.name),
      if (decision != null) ...[('Décision', decision.label), ('Raison', decision.reason)],
      if (plan != null) ...[
        ('Mode', plan.method.label),
        ('Conteneur', plan.container ?? '?'),
        ('Vidéo', plan.videoCodec ?? '?'),
        if (plan.bitrate != null) ('Débit', '${(plan.bitrate! / 1e6).toStringAsFixed(1)} Mb/s'),
        ('Audio', plan.currentAudio?.label ?? '—'),
        ('Sous-titres', plan.currentSubtitle?.label ?? 'Aucun'),
      ],
      if (size != null) ('Image', '${size.width.toInt()}×${size.height.toInt()}'),
      ('Tampon', '${(snapshot.buffered - snapshot.position).inSeconds.clamp(0, 9999)} s'),
      if (snapshot.droppedFrames != null) ('Images perdues', '${snapshot.droppedFrames}'),
      if (plan?.source?.video != null) ('Source', plan!.source!.video!.summary),
    ];
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.only(top: OFSpacing.md),
      padding: const EdgeInsets.all(OFSpacing.md),
      decoration: const BoxDecoration(color: Color(0xB3000000), borderRadius: OFRadius.mdAll),
      child: DefaultTextStyle(
        style: OFTypography.caption.copyWith(fontFamily: 'monospace', color: OFColors.textSecondary),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (k, v) in lines)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${k.padRight(12)} ',
                      style: const TextStyle(color: OFColors.textTertiary),
                    ),
                    TextSpan(text: v),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Réglage fin d'un décalage par pas de 100 ms (appui long : 1 s), remise à zéro au centre.
class _DelayStepper extends StatelessWidget {
  const _DelayStepper({required this.value, required this.onChanged, required this.hint});

  final Duration value;
  final ValueChanged<Duration> onChanged;
  final String hint;

  static const _step = Duration(milliseconds: 100);
  static const _bigStep = Duration(seconds: 1);

  @override
  Widget build(BuildContext context) {
    final ms = value.inMilliseconds;
    final label = '${ms > 0 ? '+' : ''}${(ms / 1000).toStringAsFixed(1).replaceAll('.', ',')} s';
    Widget step(IconData icon, String tooltip, Duration delta) => GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onChanged(value + (delta.isNegative ? -_bigStep : _bigStep));
      },
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon),
        onPressed: () {
          HapticFeedback.selectionClick();
          onChanged(value + delta);
        },
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: OFSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              step(Icons.remove_rounded, 'Moins 0,1 s', -_step),
              Expanded(
                child: TextButton(
                  onPressed: ms == 0 ? null : () => onChanged(Duration.zero),
                  child: Text(
                    label,
                    style: OFTypography.headline.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ),
              ),
              step(Icons.add_rounded, 'Plus 0,1 s', _step),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: OFSpacing.sm),
            child: Text(hint, style: OFTypography.caption.copyWith(color: OFColors.textTertiary)),
          ),
        ],
      ),
    );
  }
}
