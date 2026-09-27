import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/media/formatters.dart';
import '../../../core/media/media_item.dart';
import '../../../app/router.dart';
import '../../settings/presentation/settings_providers.dart';
import '../domain/playback_engine.dart';
import 'player_controller.dart';
import 'player_sheets.dart';

/// Lecteur plein écran. Même UI quel que soit le moteur : tout passe par
/// [PlayerController] et l'interface [PlaybackEngine].
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.args});

  final PlayerArgs args;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  BoxFit _fit = BoxFit.contain;

  @override
  void initState() {
    super.initState();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Téléphone : paysage forcé. Tablette : l'utilisateur garde la main.
      if (mounted && MediaQuery.sizeOf(context).shortestSide < 600) {
        unawaited(
          SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]),
        );
      }
    });
  }

  @override
  void dispose() {
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(SystemChrome.setPreferredOrientations(const []));
    super.dispose();
  }

  bool _popped = false;

  /// Fermeture ordonnée : le contrôleur envoie le rapport final, rafraîchit
  /// l'accueil et la fiche, puis passe en phase `closed` → on quitte l'écran.
  void _requestClose() => unawaited(ref.read(playerControllerProvider(widget.args).notifier).close());

  void _pop() {
    if (_popped || !mounted) return;
    _popped = true;
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = playerControllerProvider(widget.args);
    ref.listen(provider.select((s) => s.phase), (_, phase) {
      if (phase == PlayerPhase.closed) _pop();
    });
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final engine = state.engine;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (engine != null && state.phase == PlayerPhase.playing) Center(child: engine.buildView(fit: _fit)),
            switch (state.phase) {
              PlayerPhase.error => _ErrorView(
                message: state.error ?? 'Erreur de lecture.',
                // Mode debug : détail technique + accès direct aux journaux.
                detail: ref.watch(settingsProvider).debugMode ? state.technicalError : null,
                onLogs: ref.watch(settingsProvider).debugMode ? () => context.push(Routes.logs) : null,
                onClose: _requestClose,
              ),
              PlayerPhase.playing when engine != null => PlayerControls(
                state: state,
                engine: engine,
                controller: controller,
                fit: _fit,
                onToggleFit: () => setState(() => _fit = _fit == BoxFit.contain ? BoxFit.cover : BoxFit.contain),
                onClose: _requestClose,
                debugByDefault: ref.watch(settingsProvider).debugMode,
              ),
              PlayerPhase.closed => const SizedBox.shrink(),
              _ => _Preparing(title: state.item?.name, onClose: _requestClose),
            },
          ],
        ),
      ),
    );
  }
}

class _Preparing extends StatelessWidget {
  const _Preparing({required this.title, required this.onClose});

  final String? title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(dimension: 36, child: CircularProgressIndicator(strokeWidth: 2.5)),
              if (title != null) ...[
                const SizedBox(height: OFSpacing.lg),
                Text(title!, style: OFTypography.headline.copyWith(color: OFColors.textSecondary)),
              ],
            ],
          ),
        ),
        _CloseButton(onClose: onClose),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onClose, this.detail, this.onLogs});

  final String message;
  final String? detail;
  final VoidCallback? onLogs;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(OFSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: OFColors.textTertiary),
            const SizedBox(height: OFSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: OFTypography.body.copyWith(color: OFColors.textSecondary),
            ),
            if (detail != null) ...[
              const SizedBox(height: OFSpacing.md),
              SelectableText(
                detail!,
                textAlign: TextAlign.center,
                style: OFTypography.caption.copyWith(fontFamily: 'monospace', color: OFColors.textTertiary),
              ),
            ],
            const SizedBox(height: OFSpacing.xl),
            Wrap(
              spacing: OFSpacing.md,
              children: [
                if (onLogs != null) OFButton.secondary(label: 'Journaux', icon: Icons.receipt_long_outlined, onPressed: onLogs),
                OFButton.secondary(label: 'Fermer', onPressed: onClose),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(OFSpacing.md),
      child: OFIconButton(icon: Icons.close_rounded, tooltip: 'Fermer le lecteur', onPressed: onClose),
    ),
  );
}

/// Contrôles minimalistes : apparaissent au toucher, disparaissent après 4 s de lecture.
class PlayerControls extends StatefulWidget {
  const PlayerControls({
    super.key,
    required this.state,
    required this.engine,
    required this.controller,
    required this.fit,
    required this.onToggleFit,
    required this.onClose,
    this.debugByDefault = false,
  });

  /// Mode debug : l'overlay technique est affiché d'emblée.
  final bool debugByDefault;

  final PlayerUiState state;
  final PlaybackEngine engine;
  final PlayerController controller;
  final BoxFit fit;
  final VoidCallback onToggleFit;
  final VoidCallback onClose;

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  bool _visible = true;
  late bool _debug = widget.debugByDefault;
  Timer? _hideTimer;
  Duration? _scrubbing;
  _SeekFeedback? _feedback;
  Timer? _feedbackTimer;

  static const _hideAfter = Duration(seconds: 4);
  static const _skip = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideAfter, () {
      if (mounted && widget.engine.snapshot.playing && _scrubbing == null) setState(() => _visible = false);
    });
  }

  void _show() {
    setState(() => _visible = true);
    _scheduleHide();
  }

  void _toggle() {
    if (_visible) {
      _hideTimer?.cancel();
      setState(() => _visible = false);
    } else {
      _show();
    }
  }

  void _doubleTapSeek(TapDownDetails d) {
    final width = context.size?.width ?? 1;
    final forward = d.localPosition.dx > width / 2;
    HapticFeedback.lightImpact();
    unawaited(widget.controller.seekBy(forward ? _skip : -_skip));
    _feedbackTimer?.cancel();
    setState(() {
      final previous = _feedback;
      final count = previous != null && previous.forward == forward ? previous.count + 1 : 1;
      _feedback = _SeekFeedback(forward: forward, count: count);
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _feedback = null);
    });
  }

  Future<void> _openTracks() async {
    _hideTimer?.cancel();
    await showOFSheet<void>(
      context,
      builder: (_) => TracksSheet(controller: widget.controller, engine: widget.engine),
    );
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final motion = OFMotion.of(context);
    return StreamBuilder<PlayerSnapshot>(
      stream: widget.engine.snapshots,
      initialData: widget.engine.snapshot,
      builder: (context, snap) {
        final s = snap.data ?? const PlayerSnapshot();
        final showSpinner = s.buffering || s.status == PlaybackStatus.loading || widget.state.reloading;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Couche gestes SOUS les contrôles : les boutons reçoivent leurs taps
            // immédiatement (sinon le détecteur de double-tap les retarde de 300 ms),
            // les zones vides laissent passer vers cette couche.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              onDoubleTapDown: _doubleTapSeek,
              onDoubleTap: () {},
            ),
            if (_feedback != null) IgnorePointer(child: _SeekIndicator(feedback: _feedback!)),
            if (showSpinner && !_visible)
              const IgnorePointer(
                child: Center(
                  child: SizedBox.square(dimension: 36, child: CircularProgressIndicator(strokeWidth: 2.5)),
                ),
              ),
            IgnorePointer(
              ignoring: !_visible,
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: motion.standard,
                curve: OFMotion.standardCurve,
                child: _visible || motion.enabled
                    ? _ControlsLayer(
                        snapshot: s,
                        scrubbing: _scrubbing,
                        showSpinner: showSpinner,
                        debug: _debug,
                        ui: widget.state,
                        engine: widget.engine,
                        fit: widget.fit,
                        onClose: widget.onClose,
                        onPlayPause: () {
                          unawaited(widget.controller.togglePlay());
                          _show();
                        },
                        onSkip: (d) {
                          unawaited(widget.controller.seekBy(d));
                          _show();
                        },
                        onScrubStart: (p) {
                          _hideTimer?.cancel();
                          setState(() => _scrubbing = p);
                        },
                        onScrub: (p) => setState(() => _scrubbing = p),
                        onScrubEnd: (p) {
                          setState(() => _scrubbing = null);
                          unawaited(widget.controller.seek(p));
                          _scheduleHide();
                        },
                        onTracks: _openTracks,
                        onToggleFit: () {
                          widget.onToggleFit();
                          _show();
                        },
                        onToggleDebug: () => setState(() => _debug = !_debug),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SeekFeedback {
  const _SeekFeedback({required this.forward, required this.count});

  final bool forward;
  final int count;
}

class _SeekIndicator extends StatelessWidget {
  const _SeekIndicator({required this.feedback});

  final _SeekFeedback feedback;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: feedback.forward ? const Alignment(0.6, 0) : const Alignment(-0.6, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: OFSpacing.lg, vertical: OFSpacing.md),
        decoration: const BoxDecoration(
          color: Color(0x80000000),
          borderRadius: BorderRadius.all(Radius.circular(OFRadius.pill)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              feedback.forward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
              color: OFColors.textPrimary,
            ),
            const SizedBox(width: OFSpacing.sm),
            Text('${feedback.count * 10} s', style: OFTypography.headline),
          ],
        ),
      ),
    );
  }
}

class _ControlsLayer extends StatelessWidget {
  const _ControlsLayer({
    required this.snapshot,
    required this.scrubbing,
    required this.showSpinner,
    required this.debug,
    required this.ui,
    required this.engine,
    required this.fit,
    required this.onClose,
    required this.onPlayPause,
    required this.onSkip,
    required this.onScrubStart,
    required this.onScrub,
    required this.onScrubEnd,
    required this.onTracks,
    required this.onToggleFit,
    required this.onToggleDebug,
  });

  final PlayerSnapshot snapshot;
  final Duration? scrubbing;
  final bool showSpinner;
  final bool debug;
  final PlayerUiState ui;
  final PlaybackEngine engine;
  final BoxFit fit;
  final VoidCallback onClose;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSkip;
  final ValueChanged<Duration> onScrubStart;
  final ValueChanged<Duration> onScrub;
  final ValueChanged<Duration> onScrubEnd;
  final VoidCallback onTracks;
  final VoidCallback onToggleFit;
  final VoidCallback onToggleDebug;

  @override
  Widget build(BuildContext context) {
    final item = ui.item;
    final title = item?.kind == MediaKind.episode ? (item?.seriesName ?? item?.name) : item?.name;
    final subtitle = item?.kind == MediaKind.episode ? [?item?.episodeLabel, ?item?.name].join(' · ') : null;
    final duration = snapshot.duration > Duration.zero ? snapshot.duration : (ui.plan?.runtime ?? Duration.zero);
    final position = scrubbing ?? snapshot.position;

    return Stack(
      fit: StackFit.expand,
      children: [
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xB3000000), Color(0x00000000), Color(0x00000000), Color(0xCC000000)],
                stops: [0, 0.3, 0.6, 1],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: OFSpacing.lg, vertical: OFSpacing.sm),
            child: Column(
              children: [
                Row(
                  children: [
                    _RoundButton(icon: Icons.close_rounded, label: 'Fermer le lecteur', onTap: onClose),
                    const SizedBox(width: OFSpacing.md),
                    Expanded(
                      child: GestureDetector(
                        onLongPress: onToggleDebug,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (title != null)
                              Text(title, style: OFTypography.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (subtitle != null && subtitle.isNotEmpty)
                              Text(
                                subtitle,
                                style: OFTypography.caption.copyWith(color: OFColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ),
                    _RoundButton(
                      icon: fit == BoxFit.contain ? Icons.fit_screen_rounded : Icons.fullscreen_exit_rounded,
                      label: fit == BoxFit.contain ? 'Remplir l’écran' : 'Adapter à l’écran',
                      onTap: onToggleFit,
                    ),
                    const SizedBox(width: OFSpacing.sm),
                    _RoundButton(icon: Icons.subtitles_outlined, label: 'Audio et sous-titres', onTap: onTracks),
                  ],
                ),
                if (debug)
                  Align(
                    alignment: Alignment.topLeft,
                    child: DebugOverlay(ui: ui, engine: engine, snapshot: snapshot),
                  ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundButton(
                      icon: Icons.replay_10_rounded,
                      label: 'Reculer de 10 secondes',
                      size: 56,
                      onTap: () => onSkip(const Duration(seconds: -10)),
                    ),
                    const SizedBox(width: OFSpacing.xxl),
                    SizedBox.square(
                      dimension: 76,
                      child: showSpinner
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : _RoundButton(
                              icon: snapshot.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              label: snapshot.playing ? 'Pause' : 'Lecture',
                              size: 76,
                              iconSize: 40,
                              onTap: onPlayPause,
                            ),
                    ),
                    const SizedBox(width: OFSpacing.xxl),
                    _RoundButton(
                      icon: Icons.forward_10_rounded,
                      label: 'Avancer de 10 secondes',
                      size: 56,
                      onTap: () => onSkip(const Duration(seconds: 10)),
                    ),
                  ],
                ),
                const Spacer(),
                Scrubber(
                  position: position,
                  duration: duration,
                  buffered: snapshot.buffered,
                  onStart: onScrubStart,
                  onChanged: onScrub,
                  onEnd: onScrubEnd,
                ),
                Row(
                  children: [
                    Text(
                      MediaFormat.clock(position),
                      style: OFTypography.caption.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                    const Spacer(),
                    Text(
                      '-${MediaFormat.clock(duration > position ? duration - position : Duration.zero)}',
                      style: OFTypography.caption.copyWith(
                        color: OFColors.textSecondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
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

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 44,
    this.iconSize = 24,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          radius: size / 2,
          child: SizedBox.square(
            dimension: size,
            child: Icon(icon, size: iconSize, color: OFColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Barre de progression fine, épaissie pendant le glissé, avec zone tactile large.
class Scrubber extends StatelessWidget {
  const Scrubber({
    super.key,
    required this.position,
    required this.duration,
    required this.buffered,
    required this.onStart,
    required this.onChanged,
    required this.onEnd,
  });

  final Duration position;
  final Duration duration;
  final Duration buffered;
  final ValueChanged<Duration> onStart;
  final ValueChanged<Duration> onChanged;
  final ValueChanged<Duration> onEnd;

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds.toDouble();
    final accent = Theme.of(context).colorScheme.primary;
    Duration at(double v) => Duration(milliseconds: v.round());
    return Semantics(
      label: 'Position de lecture',
      value: MediaFormat.clock(position),
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: 3,
          activeTrackColor: accent,
          inactiveTrackColor: OFColors.textPrimary.withValues(alpha: 0.25),
          secondaryActiveTrackColor: OFColors.textPrimary.withValues(alpha: 0.45),
          thumbColor: OFColors.textPrimary,
          overlayShape: SliderComponentShape.noOverlay,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          trackShape: const RoundedRectSliderTrackShape(),
        ),
        child: SizedBox(
          height: 36,
          child: Slider(
            value: total <= 0 ? 0 : position.inMilliseconds.clamp(0, total).toDouble(),
            secondaryTrackValue: total <= 0 ? null : buffered.inMilliseconds.clamp(0, total).toDouble(),
            max: total <= 0 ? 1 : total,
            onChangeStart: total <= 0 ? null : (v) => onStart(at(v)),
            onChanged: total <= 0 ? null : (v) => onChanged(at(v)),
            onChangeEnd: total <= 0 ? null : (v) => onEnd(at(v)),
          ),
        ),
      ),
    );
  }
}
