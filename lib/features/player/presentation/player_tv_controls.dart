import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/media/formatters.dart';
import '../../../core/media/media_item.dart';
import '../domain/playback_engine.dart';
import 'player_controller.dart';
import 'player_menu.dart';
import 'player_overlays.dart';
import 'player_screen.dart' show Scrubber;
import 'player_sheets.dart';

/// Contrôles du lecteur sur téléviseur, pensés pour la télécommande (à la manière de
/// l'Apple TV et de Google TV) : tout est en bas de l'écran, lisible à trois mètres.
///
/// - titre, barre de progression pleine largeur, temps écoulé, heure de fin et temps restant ;
/// - une rangée de boutons : ±10 s et lecture/pause à gauche, sous-titres, audio, format et
///   réglages à droite. Le bouton focalisé devient une pilule blanche avec son libellé ;
/// - ▲ depuis les boutons : la barre de progression (◀ ▶ pour chercher avec aperçu).
class TvPlayerControls extends StatelessWidget {
  const TvPlayerControls({
    super.key,
    required this.snapshot,
    required this.scrubbing,
    required this.showSpinner,
    required this.debug,
    required this.ui,
    required this.engine,
    required this.fit,
    required this.onPlayPause,
    required this.onSkip,
    required this.onScrubStart,
    required this.onScrub,
    required this.onScrubEnd,
    required this.onMenu,
    required this.onCycleFit,
    required this.playFocus,
  });

  final PlayerSnapshot snapshot;
  final Duration? scrubbing;
  final bool showSpinner;
  final bool debug;
  final PlayerUiState ui;
  final PlaybackEngine engine;
  final BoxFit fit;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSkip;
  final ValueChanged<Duration> onScrubStart;
  final ValueChanged<Duration> onScrub;
  final ValueChanged<Duration> onScrubEnd;
  final ValueChanged<PlayerMenuPage> onMenu;
  final VoidCallback onCycleFit;
  final FocusNode playFocus;

  /// Marges de sécurité des téléviseurs (5 % de l'image peut être rogné).
  static const safeX = 48.0;
  static const safeY = 28.0;

  @override
  Widget build(BuildContext context) {
    final item = ui.item;
    final episode = item?.kind == MediaKind.episode;
    final title = episode ? (item?.seriesName ?? item?.name) : item?.name;
    final subtitle = episode ? [?item?.episodeLabel, ?item?.name].join(' · ') : null;
    final duration = snapshot.duration > Duration.zero ? snapshot.duration : (ui.plan?.runtime ?? Duration.zero);
    final position = scrubbing ?? snapshot.position;
    final remaining = duration > position ? duration - position : Duration.zero;
    final chapter = ui.extras.chapterAt(position);
    final times = OFTypography.callout.copyWith(
      color: OFColors.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final end = DateTime.now().add(remaining * (1 / (snapshot.rate > 0 ? snapshot.rate : 1)));
    final endsAt = '${end.hour} h ${end.minute.toString().padLeft(2, '0')}';
    final plan = ui.plan;
    final hasAudio = (plan?.audioTracks.length ?? 0) > 1;
    final (fitIcon, fitLabel) = switch (fit) {
      BoxFit.contain => (Icons.fit_screen_rounded, 'Zoom'),
      BoxFit.cover => (Icons.aspect_ratio_rounded, 'Étirer'),
      _ => (Icons.fullscreen_exit_rounded, 'Original'),
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        // Voile bas : texte lisible sur n'importe quelle image.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0x00000000), Color(0x00000000), Color(0xD9000000)],
                stops: [0, 0.2, 0.45, 1],
              ),
            ),
          ),
        ),
        if (debug)
          Positioned(
            top: safeY,
            left: safeX,
            child: DebugOverlay(ui: ui, engine: engine, snapshot: snapshot),
          ),
        Positioned(
          left: safeX,
          right: safeX,
          bottom: safeY,
          child: FocusTraversalGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title,
                    style: OFTypography.title2.copyWith(fontSize: 26),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (subtitle != null && subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      style: OFTypography.body.copyWith(color: OFColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: OFSpacing.md),
                Scrubber(
                  position: position,
                  duration: duration,
                  buffered: snapshot.buffered,
                  scrubbing: scrubbing != null,
                  preview: scrubbing == null
                      ? null
                      : (ui.extras.trickplay != null && plan != null
                            ? TrickplayPreview(
                                manifest: ui.extras.trickplay!,
                                itemId: plan.itemId,
                                mediaSourceId: plan.mediaSourceId,
                                position: position,
                                width: 220,
                              )
                            : ScrubLabel(position: position, chapter: chapter)),
                  onStart: onScrubStart,
                  onChanged: onScrub,
                  onEnd: onScrubEnd,
                ),
                Row(
                  children: [
                    Text(MediaFormat.clock(position), style: times),
                    const SizedBox(width: OFSpacing.md),
                    Expanded(
                      child: chapter != null && scrubbing == null
                          ? Text(
                              chapter.name,
                              style: times.copyWith(color: OFColors.textTertiary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : const SizedBox.shrink(),
                    ),
                    if (duration > Duration.zero)
                      Text('Fin à $endsAt', style: times.copyWith(color: OFColors.textTertiary)),
                    const SizedBox(width: OFSpacing.lg),
                    Text('-${MediaFormat.clock(remaining)}', style: times),
                  ],
                ),
                const SizedBox(height: OFSpacing.md),
                Row(
                  children: [
                    TvControlButton(
                      icon: Icons.replay_10_rounded,
                      label: '-10 s',
                      onPressed: () => onSkip(const Duration(seconds: -10)),
                    ),
                    const SizedBox(width: OFSpacing.sm),
                    TvControlButton(
                      icon: snapshot.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      label: snapshot.playing ? 'Pause' : 'Lecture',
                      focusNode: playFocus,
                      autofocus: true,
                      loading: showSpinner,
                      onPressed: onPlayPause,
                    ),
                    const SizedBox(width: OFSpacing.sm),
                    TvControlButton(
                      icon: Icons.forward_10_rounded,
                      label: '+10 s',
                      onPressed: () => onSkip(const Duration(seconds: 10)),
                    ),
                    const Spacer(),
                    TvControlButton(
                      icon: Icons.closed_caption_outlined,
                      label: 'Sous-titres',
                      onPressed: () => onMenu(PlayerMenuPage.subtitles),
                    ),
                    if (hasAudio) ...[
                      const SizedBox(width: OFSpacing.sm),
                      TvControlButton(
                        icon: Icons.graphic_eq_rounded,
                        label: 'Audio',
                        onPressed: () => onMenu(PlayerMenuPage.audio),
                      ),
                    ],
                    const SizedBox(width: OFSpacing.sm),
                    TvControlButton(icon: fitIcon, label: fitLabel, onPressed: onCycleFit),
                    const SizedBox(width: OFSpacing.sm),
                    TvControlButton(
                      icon: Icons.tune_rounded,
                      label: 'Réglages',
                      onPressed: () => onMenu(PlayerMenuPage.root),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Bouton du lecteur TV : icône seule au repos, pilule blanche avec libellé au focus.
class TvControlButton extends StatefulWidget {
  const TvControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.focusNode,
    this.autofocus = false,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool loading;

  @override
  State<TvControlButton> createState() => _TvControlButtonState();
}

class _TvControlButtonState extends State<TvControlButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final motion = OFMotion.of(context);
    final fg = _focused ? OFColors.background : OFColors.textPrimary;
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: TvFocusable(
        ring: false,
        scale: 1.04,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onSelect: widget.onPressed,
        onFocusChange: (f) => setState(() => _focused = f),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onPressed();
          },
          child: AnimatedContainer(
            duration: motion.fast,
            curve: OFMotion.standardCurve,
            height: 44,
            padding: EdgeInsets.symmetric(horizontal: _focused ? OFSpacing.lg : OFSpacing.sm + 2),
            decoration: BoxDecoration(
              color: _focused ? OFColors.textPrimary : const Color(0x1FFFFFFF),
              borderRadius: const BorderRadius.all(Radius.circular(OFRadius.pill)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 26,
                  child: widget.loading
                      ? Center(child: OFLoader(size: 18, color: fg))
                      : Icon(widget.icon, size: 26, color: fg),
                ),
                AnimatedSize(
                  duration: motion.fast,
                  curve: OFMotion.standardCurve,
                  child: _focused
                      ? Padding(
                          padding: const EdgeInsets.only(left: OFSpacing.sm),
                          child: Text(
                            widget.label,
                            style: OFTypography.callout.copyWith(color: fg, fontWeight: FontWeight.w600),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
