import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:optifin_native_player/optifin_native_player.dart' show AirPlayButton;
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/media/formatters.dart';
import '../../../core/media/media_item.dart';
import '../../../app/router.dart';
import '../../settings/presentation/settings_providers.dart';
import '../domain/playback_engine.dart';
import '../domain/playback_extras.dart';
import 'player_controller.dart';
import 'player_overlays.dart';
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
    // Enchaînement d'épisodes : le lecteur de l'épisode suivant remplace celui-ci.
    final next = ref.read(playerControllerProvider(widget.args)).nextItemId;
    if (next != null) {
      context.pushReplacement(Routes.play(next));
    } else if (context.canPop()) {
      context.pop();
    }
  }

  /// Contenu → zoom (recadré) → étiré → contenu.
  void _cycleFit() => setState(
    () => _fit = switch (_fit) {
      BoxFit.contain => BoxFit.cover,
      BoxFit.cover => BoxFit.fill,
      _ => BoxFit.contain,
    },
  );

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
              // Picture-in-Picture Android : seule la vidéo est visible dans la fenêtre réduite.
              PlayerPhase.playing when state.pictureInPicture => const SizedBox.shrink(),
              PlayerPhase.playing when engine != null => PlayerControls(
                state: state,
                engine: engine,
                controller: controller,
                fit: _fit,
                onCycleFit: _cycleFit,
                onClose: _requestClose,
                autoPlayNext: ref.watch(settingsProvider).autoPlayNext,
                debugByDefault: ref.watch(settingsProvider).debugMode,
              ),
              PlayerPhase.closed => const SizedBox.shrink(),
              _ => _Preparing(title: state.item?.name, notice: state.notice, onClose: _requestClose),
            },
            // Bascule automatique de moteur : information discrète, sans interrompre.
            if (state.notice != null && state.phase == PlayerPhase.playing)
              Positioned(
                top: MediaQuery.paddingOf(context).top + OFSpacing.lg,
                left: 0,
                right: 0,
                child: IgnorePointer(child: Center(child: _NoticePill(state.notice!))),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoticePill extends StatelessWidget {
  const _NoticePill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Color(0xB3000000),
      borderRadius: BorderRadius.all(Radius.circular(OFRadius.pill)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: OFSpacing.lg, vertical: OFSpacing.sm),
      child: Text(text, style: OFTypography.callout.copyWith(color: OFColors.textSecondary)),
    ),
  );
}

class _Preparing extends StatelessWidget {
  const _Preparing({required this.title, this.notice, required this.onClose});

  final String? title;
  final String? notice;
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
              if (notice != null) ...[
                const SizedBox(height: OFSpacing.sm),
                Text(notice!, style: OFTypography.callout.copyWith(color: OFColors.textTertiary)),
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
                if (onLogs != null)
                  OFButton.secondary(label: 'Journaux', icon: Icons.receipt_long_outlined, onPressed: onLogs),
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
///
/// Gestes : toucher = afficher/masquer, double-toucher = ±10 s, glissé vertical à
/// gauche = luminosité, à droite = volume. Verrou : plus aucun geste jusqu'au déverrouillage.
class PlayerControls extends StatefulWidget {
  const PlayerControls({
    super.key,
    required this.state,
    required this.engine,
    required this.controller,
    required this.fit,
    required this.onCycleFit,
    required this.onClose,
    this.autoPlayNext = true,
    this.debugByDefault = false,
  });

  /// Mode debug : l'overlay technique est affiché d'emblée.
  final bool debugByDefault;
  final bool autoPlayNext;

  final PlayerUiState state;
  final PlaybackEngine engine;
  final PlayerController controller;
  final BoxFit fit;
  final VoidCallback onCycleFit;
  final VoidCallback onClose;

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

enum _Level { brightness, volume }

class _PlayerControlsState extends State<PlayerControls> {
  bool _visible = true;
  late bool _debug = widget.debugByDefault;
  Timer? _hideTimer;
  Duration? _scrubbing;
  _SeekFeedback? _feedback;
  Timer? _feedbackTimer;

  bool _locked = false;
  bool _showUnlock = false;
  Timer? _unlockTimer;

  _Level? _level;
  double _brightness = 0.5;
  double _volume = 0.5;
  double _dragStartValue = 0;
  double _dragDistance = 0;

  static const _hideAfter = Duration(seconds: 4);
  static const _skip = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _scheduleHide();
    unawaited(_readLevels());
  }

  /// Valeurs de départ des gestes. Plugins absents (tests, plateforme) : valeurs par défaut.
  Future<void> _readLevels() async {
    try {
      _brightness = await ScreenBrightness.instance.application;
    } catch (_) {}
    try {
      VolumeController.instance.showSystemUI = false;
      _volume = await VolumeController.instance.getVolume();
    } catch (_) {}
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _feedbackTimer?.cancel();
    _unlockTimer?.cancel();
    // La luminosité revient à celle du système en quittant le lecteur.
    unawaited(ScreenBrightness.instance.resetApplicationScreenBrightness().catchError((Object _) {}));
    try {
      VolumeController.instance.showSystemUI = true;
    } catch (_) {}
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
    if (_locked) {
      _flashUnlock();
      return;
    }
    if (_visible) {
      _hideTimer?.cancel();
      setState(() => _visible = false);
    } else {
      _show();
    }
  }

  void _flashUnlock() {
    _unlockTimer?.cancel();
    setState(() => _showUnlock = true);
    _unlockTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showUnlock = false);
    });
  }

  void _lock() {
    HapticFeedback.mediumImpact();
    _hideTimer?.cancel();
    setState(() {
      _locked = true;
      _visible = false;
    });
    _flashUnlock();
  }

  void _unlock() {
    HapticFeedback.mediumImpact();
    _unlockTimer?.cancel();
    setState(() {
      _locked = false;
      _showUnlock = false;
    });
    _show();
  }

  void _doubleTapSeek(TapDownDetails d) {
    if (_locked) return;
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

  // ------------------------------------------------------------ Luminosité / volume

  void _levelStart(DragStartDetails d) {
    if (_locked) return;
    final width = context.size?.width ?? 1;
    final level = d.localPosition.dx < width / 2 ? _Level.brightness : _Level.volume;
    _dragDistance = 0;
    _dragStartValue = level == _Level.brightness ? _brightness : _volume;
    setState(() => _level = level);
  }

  void _levelUpdate(DragUpdateDetails d) {
    final level = _level;
    if (level == null) return;
    final height = context.size?.height ?? 1;
    _dragDistance += d.delta.dy;
    // Toute la hauteur de l'écran ≈ toute la plage.
    final value = (_dragStartValue - _dragDistance / (height * 0.8)).clamp(0.0, 1.0);
    setState(() {
      if (level == _Level.brightness) {
        _brightness = value;
      } else {
        _volume = value;
      }
    });
    unawaited(
      (level == _Level.brightness
              ? ScreenBrightness.instance.setApplicationScreenBrightness(value)
              : VolumeController.instance.setVolume(value))
          .catchError((Object _) {}),
    );
  }

  void _levelEnd([DragEndDetails? _]) {
    if (_level != null) setState(() => _level = null);
  }

  // ------------------------------------------------------------ Feuilles

  Future<void> _openSheet(WidgetBuilder builder) async {
    _hideTimer?.cancel();
    await showOFSheet<void>(context, builder: builder);
    _scheduleHide();
  }

  Future<void> _openTracks() => _openSheet(
    (_) => TracksSheet(
      controller: widget.controller,
      engine: widget.engine,
      onSearchSubtitles: () {
        Navigator.of(context).pop();
        unawaited(_openSheet((_) => SubtitleSearchSheet(controller: widget.controller)));
      },
    ),
  );

  Future<void> _openChapters(Duration position) {
    final extras = widget.state.extras;
    return _openSheet(
      (sheetContext) => ChaptersSheet(
        itemId: widget.state.plan?.itemId ?? '',
        chapters: extras.chapters,
        current: extras.chapterAt(position),
        onSelect: (c) {
          Navigator.of(sheetContext).pop();
          unawaited(widget.controller.seek(c.start));
        },
      ),
    );
  }

  Future<void> _pictureInPicture() async {
    final ok = await widget.controller.enterPictureInPicture();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Picture-in-Picture indisponible pour cette lecture.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final motion = OFMotion.of(context);
    final ui = widget.state;
    final next = ui.extras.nextEpisode;
    return StreamBuilder<PlayerSnapshot>(
      stream: widget.engine.snapshots,
      initialData: widget.engine.snapshot,
      builder: (context, snap) {
        final s = snap.data ?? const PlayerSnapshot();
        final showSpinner = s.buffering || s.status == PlaybackStatus.loading || ui.reloading;
        final bottomInset = MediaQuery.paddingOf(context).bottom;
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
              onVerticalDragStart: _levelStart,
              onVerticalDragUpdate: _levelUpdate,
              onVerticalDragEnd: _levelEnd,
              onVerticalDragCancel: _levelEnd,
            ),
            if (_feedback != null) IgnorePointer(child: _SeekIndicator(feedback: _feedback!)),
            if (_level != null)
              IgnorePointer(
                child: Align(
                  alignment: const Alignment(0, -0.7),
                  child: LevelIndicator(
                    icon: _level == _Level.brightness ? Icons.brightness_6_rounded : Icons.volume_up_rounded,
                    value: _level == _Level.brightness ? _brightness : _volume,
                  ),
                ),
              ),
            if (showSpinner && !_visible)
              const IgnorePointer(
                child: Center(
                  child: SizedBox.square(dimension: 36, child: CircularProgressIndicator(strokeWidth: 2.5)),
                ),
              ),
            IgnorePointer(
              ignoring: !_visible || _locked,
              child: AnimatedOpacity(
                opacity: _visible && !_locked ? 1 : 0,
                duration: motion.standard,
                curve: OFMotion.standardCurve,
                child: (_visible && !_locked) || motion.enabled
                    ? _ControlsLayer(
                        snapshot: s,
                        scrubbing: _scrubbing,
                        showSpinner: showSpinner,
                        debug: _debug,
                        ui: ui,
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
                        onChapters: ui.extras.chapters.isEmpty ? null : () => _openChapters(s.position),
                        onPictureInPicture: widget.engine.capabilities.pictureInPicture ? _pictureInPicture : null,
                        onLock: _lock,
                        onCycleFit: () {
                          widget.onCycleFit();
                          _show();
                        },
                        onToggleDebug: () => setState(() => _debug = !_debug),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            // « Passer l'intro » : visible même contrôles masqués (mais pas verrouillé).
            if (ui.segment != null && !_locked && !ui.upNext)
              Positioned(
                right: OFSpacing.xl,
                bottom: bottomInset + (_visible ? 112 : OFSpacing.xxl),
                child: FadeSlideIn(
                  key: ValueKey(ui.segment),
                  axis: Axis.horizontal,
                  offset: 32,
                  child: SkipSegmentButton(segment: ui.segment!, onSkip: widget.controller.skipSegment),
                ),
              ),
            if (ui.upNext && next != null && !_locked)
              Positioned(
                right: OFSpacing.xl,
                bottom: bottomInset + (_visible ? 112 : OFSpacing.xxl),
                child: FadeSlideIn(
                  key: ValueKey('suivant-${next.id}'),
                  axis: Axis.horizontal,
                  offset: 48,
                  child: UpNextCard(
                    key: ValueKey(next.id),
                    next: next,
                    autoPlay: widget.autoPlayNext,
                    onPlay: () => unawaited(widget.controller.playNext()),
                    onDismiss: widget.controller.dismissUpNext,
                  ),
                ),
              ),
            if (_locked)
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomInset + OFSpacing.xxl,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _showUnlock ? 1 : 0,
                    duration: motion.standard,
                    child: IgnorePointer(
                      ignoring: !_showUnlock,
                      child: OFButton.secondary(
                        label: 'Déverrouiller',
                        icon: Icons.lock_open_rounded,
                        onPressed: _unlock,
                      ),
                    ),
                  ),
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
    required this.onChapters,
    required this.onPictureInPicture,
    required this.onLock,
    required this.onCycleFit,
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
  final VoidCallback? onChapters;
  final VoidCallback? onPictureInPicture;
  final VoidCallback onLock;
  final VoidCallback onCycleFit;
  final VoidCallback onToggleDebug;

  @override
  Widget build(BuildContext context) {
    final item = ui.item;
    final title = item?.kind == MediaKind.episode ? (item?.seriesName ?? item?.name) : item?.name;
    final subtitle = item?.kind == MediaKind.episode ? [?item?.episodeLabel, ?item?.name].join(' · ') : null;
    final duration = snapshot.duration > Duration.zero ? snapshot.duration : (ui.plan?.runtime ?? Duration.zero);
    final position = scrubbing ?? snapshot.position;
    final chapter = ui.extras.chapterAt(position);
    final (fitIcon, fitLabel) = switch (fit) {
      BoxFit.contain => (Icons.fit_screen_rounded, 'Zoomer (remplir l’écran)'),
      BoxFit.cover => (Icons.aspect_ratio_rounded, 'Étirer à l’écran'),
      _ => (Icons.fullscreen_exit_rounded, 'Format d’origine'),
    };

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
                    if (engine.capabilities.airPlay) const AirPlayButton(),
                    if (onPictureInPicture != null)
                      _RoundButton(
                        icon: Icons.picture_in_picture_alt_rounded,
                        label: 'Picture-in-Picture',
                        onTap: onPictureInPicture!,
                      ),
                    if (onChapters != null)
                      _RoundButton(icon: Icons.list_rounded, label: 'Chapitres', onTap: onChapters!),
                    _RoundButton(icon: fitIcon, label: fitLabel, onTap: onCycleFit),
                    _RoundButton(icon: Icons.lock_outline_rounded, label: 'Verrouiller l’écran', onTap: onLock),
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
                if (chapter != null && scrubbing == null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      chapter.name,
                      style: OFTypography.caption.copyWith(color: OFColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Scrubber(
                  position: position,
                  duration: duration,
                  buffered: snapshot.buffered,
                  chapters: ui.extras.chapters,
                  scrubbing: scrubbing != null,
                  preview: scrubbing == null
                      ? null
                      : (ui.extras.trickplay != null && ui.plan != null
                            ? TrickplayPreview(
                                manifest: ui.extras.trickplay!,
                                itemId: ui.plan!.itemId,
                                mediaSourceId: ui.plan!.mediaSourceId,
                                position: position,
                              )
                            : ScrubLabel(position: position, chapter: chapter)),
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

/// Barre de progression fine avec zone tactile large, repères de chapitres et,
/// pendant le glissé, une prévisualisation (vignette trickplay ou heure) au-dessus du doigt.
class Scrubber extends StatelessWidget {
  const Scrubber({
    super.key,
    required this.position,
    required this.duration,
    required this.buffered,
    required this.onStart,
    required this.onChanged,
    required this.onEnd,
    this.chapters = const [],
    this.scrubbing = false,
    this.preview,
  });

  final Duration position;
  final Duration duration;
  final Duration buffered;
  final List<Chapter> chapters;
  final bool scrubbing;
  final Widget? preview;
  final ValueChanged<Duration> onStart;
  final ValueChanged<Duration> onChanged;
  final ValueChanged<Duration> onEnd;

  /// Marge du rail du Slider (rayon du curseur).
  static const _inset = 7.0;

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds.toDouble();
    final accent = Theme.of(context).colorScheme.primary;
    Duration at(double v) => Duration(milliseconds: v.round());
    double fraction(Duration d) => total <= 0 ? 0 : (d.inMilliseconds / total).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final track = constraints.maxWidth - _inset * 2;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Semantics(
              label: 'Position de lecture',
              value: MediaFormat.clock(position),
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: scrubbing ? 5 : 3,
                  activeTrackColor: accent,
                  inactiveTrackColor: OFColors.textPrimary.withValues(alpha: 0.25),
                  secondaryActiveTrackColor: OFColors.textPrimary.withValues(alpha: 0.45),
                  thumbColor: OFColors.textPrimary,
                  overlayShape: SliderComponentShape.noOverlay,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: _inset),
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
            ),
            // Repères de chapitres : fines coupures dans le rail.
            for (final c in chapters)
              if (c.start > Duration.zero && fraction(c.start) < 1)
                Positioned(
                  left: _inset + track * fraction(c.start) - 1,
                  top: 36 / 2 - 4,
                  child: const IgnorePointer(
                    child: SizedBox(width: 2, height: 8, child: ColoredBox(color: Color(0xCC000000))),
                  ),
                ),
            if (preview != null)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Align(
                    // Centré sur le doigt, sans déborder de l'écran.
                    alignment: Alignment(fraction(position) * 2 - 1, 1),
                    child: preview,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
