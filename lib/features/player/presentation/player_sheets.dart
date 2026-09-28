import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design_system/design_system.dart';
import '../domain/playback_engine.dart';
import 'player_controller.dart';

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
class DelayStepper extends StatelessWidget {
  const DelayStepper({super.key, required this.value, required this.onChanged, required this.hint});

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
