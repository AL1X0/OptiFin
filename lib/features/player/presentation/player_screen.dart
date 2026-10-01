import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/gestures.dart';
import 'package:optifin_native_player/optifin_native_player.dart' show AirPlayButton, NativePlayers;
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/media/formatters.dart';
import '../../../core/media/media_item.dart';
import '../../../app/router.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/engines/windows_mpv_engine.dart';
import '../domain/engine_selector.dart';
import '../domain/playback_engine.dart';
import 'player_controller.dart';
import 'player_overlays.dart';
import 'player_media_session.dart';
import 'player_menu.dart';
import 'player_sheets.dart';
import 'player_tv_controls.dart';

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
    // Ordinateur : pas de mise en veille pendant la lecture.
    unawaited(NativePlayers.keepAwake(true).catchError((Object _) {}));
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
    unawaited(NativePlayers.keepAwake(false).catchError((Object _) {}));
    super.dispose();
  }

  bool _popped = false;

  /// Fermeture ordonnée : le contrôleur envoie le rapport final, rafraîchit
  /// l'accueil et la fiche, puis passe en phase `closed` → on quitte l'écran.
  void _requestClose() => unawaited(ref.read(playerControllerProvider(widget.args).notifier).close());

  final _back = PlayerBack();

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

    final screen = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // Retour : d'abord le menu (et, sur TV, les contrôles), puis la fermeture du lecteur.
        if (!didPop && !(_back.handle?.call() ?? false)) _requestClose();
      },
      child: Scaffold(
        // Windows : la vidéo mpv est dessinée SOUS l'interface, qui doit rester transparente.
        backgroundColor: engine is WindowsMpvEngine && state.phase == PlayerPhase.playing
            ? Colors.transparent
            : Colors.black,
        // Vue native (AVPlayer, Media3) sous les commandes : verre teinté sans flou.
        body: _withNativeGlass(
          engine,
          GlassBlur(
            enabled: state.decision?.engine != EngineKind.native,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (engine != null && state.phase == PlayerPhase.playing)
                  Center(
                    child: KeyedSubtree(
                      key: _videoKey,
                      child: engine.buildView(fit: _fit),
                    ),
                  ),
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
                    back: _back,
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
        ),
      ),
    );
    // Ordinateur : lecture visible et pilotable par Windows (touches média, barre des tâches).
    return OFDevice.desktop ? PlayerMediaSession(args: widget.args, child: screen) : screen;
  }

  final _videoKey = GlobalKey();

  /// iOS + AVPlayer : le verre des commandes est dessiné par la vue vidéo native
  /// (Liquid Glass), Flutter n'y peint que les icônes et le liseré.
  Widget _withNativeGlass(PlaybackEngine? engine, Widget child) {
    if (engine is! NativeGlassHost) return child;
    final host = engine as NativeGlassHost;
    if (!host.nativeGlass) return child;
    return NativeGlassScope(key: ObjectKey(engine), anchorKey: _videoKey, onChanged: host.setGlass, child: child);
  }
}

class _NoticePill extends StatelessWidget {
  const _NoticePill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => LiquidGlass(
    shade: 0.45,
    padding: const EdgeInsets.symmetric(horizontal: OFSpacing.lg, vertical: OFSpacing.sm),
    child: Text(text, style: OFTypography.callout.copyWith(color: OFColors.textSecondary)),
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
              OFLoader.glass(size: 72),
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
      child: OFGlassButton(icon: Icons.close_rounded, label: 'Fermer le lecteur', onPressed: onClose),
    ),
  );
}

/// Contrôles minimalistes en verre : apparaissent au toucher, disparaissent après 4 s de lecture.
///
/// En haut : fermer, titre, puis AirPlay, Picture-in-Picture, format d'image et Réglages
/// (tout le reste : audio, sous-titres, chapitres, vitesse, synchronisation, moteur, verrou).
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
    this.back,
    this.autoPlayNext = true,
    this.debugByDefault = false,
  });

  /// Bouton Retour : les contrôles le traitent d'abord (menu, et sur TV contrôles affichés).
  final PlayerBack? back;

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

/// Relais du bouton Retour entre l'écran du lecteur et ses contrôles.
class PlayerBack {
  /// true si le retour a été consommé (menu fermé, contrôles masqués).
  bool Function()? handle;
}

enum _Level { brightness, volume }

class _PlayerControlsState extends State<PlayerControls> {
  /// Chaque changement d'état (contrôles affichés/masqués, menu, verrou, glissé) peut
  /// déplacer les formes de verre : leur suivi natif est relancé.
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    NativeGlassScope.maybeOf(context)?.wake();
  }

  bool _visible = true;
  late bool _debug = widget.debugByDefault;
  Timer? _hideTimer;
  Duration? _scrubbing;
  _SeekFeedback? _feedback;
  Timer? _feedbackTimer;
  bool _menu = false;
  PlayerMenuPage _menuPage = PlayerMenuPage.root;

  bool _locked = false;
  bool _showUnlock = false;
  Timer? _unlockTimer;

  _Level? _level;

  /// Ordinateur : plein écran (F, double-clic), indicateur de volume éphémère.
  bool _fullscreen = false;
  Timer? _levelTimer;

  VolumeControl? get _volumeControl => widget.engine is VolumeControl ? widget.engine as VolumeControl : null;
  double _brightness = 0.5;
  double _volume = 0.5;
  double _dragStartValue = 0;
  double _dragDistance = 0;

  static const _hideAfter = Duration(seconds: 4);
  static const _skip = Duration(seconds: 10);

  /// Racine des touches (télécommande, clavier) quand aucun bouton n'a le focus.
  /// Hors du parcours des flèches : il couvre tout l'écran et capterait le focus entre deux boutons.
  final _keys = FocusNode(debugLabel: 'lecteur', skipTraversal: true);

  /// Bouton lecture/pause : le focus y va quand les contrôles apparaissent à la télécommande.
  final _playFocus = FocusNode(debugLabel: 'lecture/pause');

  @override
  void initState() {
    super.initState();
    _scheduleHide();
    unawaited(_readLevels());
    widget.back?.handle = _handleBack;
  }

  bool _handleBack() {
    if (_menu) {
      _closeMenu();
      return true;
    }
    // TV : Retour masque d'abord les contrôles (comme sur l'Apple TV), puis quitte.
    if (OFDevice.tv && _visible) {
      _hide();
      return true;
    }
    return false;
  }

  void _hide() {
    _hideTimer?.cancel();
    setState(() => _visible = false);
    // Plus aucun bouton visible : les touches reviennent au lecteur.
    _keys.requestFocus();
  }

  void _seekBy(Duration delta) {
    unawaited(widget.controller.seekBy(delta));
    _feedbackTimer?.cancel();
    setState(() {
      final forward = delta > Duration.zero;
      final previous = _feedback;
      final count = previous != null && previous.forward == forward ? previous.count + 1 : 1;
      _feedback = _SeekFeedback(forward: forward, count: count);
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _feedback = null);
    });
  }

  /// Télécommande et clavier.
  /// - touches média : lecture/pause, avance et retour rapides, toujours ;
  /// - contrôles masqués : OK = lecture/pause, ◀ ▶ = ∓10 s (maintenu : ∓30 s),
  ///   ▲ ▼ = afficher les contrôles, focus sur lecture/pause ;
  /// - contrôles affichés : les flèches passent d'un bouton à l'autre (chaque touche
  ///   repousse leur masquage).
  // ------------------------------------------------------------ Ordinateur

  void _toggleFullscreen() {
    setState(() => _fullscreen = !_fullscreen);
    unawaited(NativePlayers.setFullscreen(_fullscreen).catchError((Object _) {}));
  }

  void _changeVolume(double delta) {
    final control = _volumeControl;
    if (control == null) return;
    final value = (control.volume + delta).clamp(0.0, 1.0);
    unawaited(control.setVolume(value));
    _flashLevel(value);
  }

  void _toggleMute() {
    final control = _volumeControl;
    if (control == null) return;
    final muted = !control.muted;
    unawaited(control.setMuted(muted));
    _flashLevel(muted ? 0 : control.volume);
  }

  void _flashLevel(double value) {
    _levelTimer?.cancel();
    setState(() {
      _level = _Level.volume;
      _volume = value;
    });
    _levelTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _level = null);
    });
  }

  /// Raccourcis du lecteur sur ordinateur (comme les lecteurs vidéo de bureau) :
  /// Espace / K lecture-pause, ← → ∓10 s, ↑ ↓ volume, M muet, F ou F11 plein écran,
  /// Échap sort du plein écran. null : touche non gérée ici.
  KeyEventResult? _desktopKey(KeyEvent event) {
    final key = event.logicalKey;
    // Combinaisons (Ctrl+F…) : laissées à l'appli.
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed || keyboard.isAltPressed || keyboard.isMetaPressed) return null;
    final repeat = event is KeyRepeatEvent;
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      if (!repeat) unawaited(widget.controller.togglePlay());
      _show();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      _seekBy(key == LogicalKeyboardKey.arrowRight ? _skip : -_skip);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      _changeVolume(key == LogicalKeyboardKey.arrowUp ? 0.05 : -0.05);
      return KeyEventResult.handled;
    }
    if (repeat) return null;
    if (key == LogicalKeyboardKey.keyM) {
      _toggleMute();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyV && widget.engine is WindowsMpvEngine) {
      unawaited(_cycleVideoLayout());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF || key == LogicalKeyboardKey.f11) {
      _toggleFullscreen();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      // Échap : sort du plein écran, sinon quitte le lecteur.
      if (_fullscreen) {
        _toggleFullscreen();
      } else {
        widget.onClose();
      }
      return KeyEventResult.handled;
    }
    return null;
  }

  /// Windows : l'image reste noire avec certains pilotes graphiques ; V essaie l'assemblage
  /// suivant (retenu ensuite pour toutes les lectures).
  Future<void> _cycleVideoLayout() async {
    final mode = await (widget.engine as WindowsMpvEngine).cycleVideoLayout();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Affichage vidéo : mode ${mode + 1} sur 3 (V pour essayer le suivant)'),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  /// Souris : les contrôles apparaissent au moindre mouvement (et le curseur avec eux).
  void _onHover() {
    if (!_visible) {
      _show();
    } else if (!_menu) {
      _scheduleHide();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (OFDevice.desktop && !_menu) {
      final handled = _desktopKey(event);
      if (handled != null) return handled;
    }
    final key = event.logicalKey;
    final repeat = event is KeyRepeatEvent;
    if (key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.mediaPause) {
      if (!repeat) unawaited(widget.controller.togglePlay());
      _show();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaFastForward || key == LogicalKeyboardKey.mediaRewind) {
      _seekBy(key == LogicalKeyboardKey.mediaFastForward ? _skip : -_skip);
      return KeyEventResult.handled;
    }
    if (_locked) return KeyEventResult.ignored;
    if (!_visible && !_menu) {
      if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
        // « Passer l'intro » ou « Épisode suivant » à l'écran : OK les déclenche (comme sur Netflix).
        final ui = widget.state;
        if (!repeat && ui.upNext && ui.extras.nextEpisode != null) {
          unawaited(widget.controller.playNext());
          return KeyEventResult.handled;
        }
        if (!repeat && ui.segment != null) {
          unawaited(widget.controller.skipSegment());
          return KeyEventResult.handled;
        }
        if (!repeat) {
          unawaited(widget.controller.togglePlay());
          _show();
          _playFocus.requestFocus();
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
        final step = repeat ? const Duration(seconds: 30) : _skip;
        _seekBy(key == LogicalKeyboardKey.arrowRight ? step : -step);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
        _show();
        _playFocus.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    // Contrôles affichés : navigation normale entre les boutons.
    if (!_menu) _scheduleHide();
    if (FocusManager.instance.primaryFocus == _keys) {
      _playFocus.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Valeurs de départ des gestes. Plugins absents (tests, plateforme) : valeurs par défaut.
  Future<void> _readLevels() async {
    // Ordinateur : volume propre au lecteur, pas de luminosité d'écran.
    if (OFDevice.desktop) {
      _volume = _volumeControl?.volume ?? 1;
      return;
    }
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
    if (widget.back?.handle == _handleBack) widget.back?.handle = null;
    _keys.dispose();
    _playFocus.dispose();
    _levelTimer?.cancel();
    if (_fullscreen) unawaited(NativePlayers.setFullscreen(false).catchError((Object _) {}));
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
      if (mounted && widget.engine.snapshot.playing && _scrubbing == null && !_menu) _hide();
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
    if (_menu) {
      _closeMenu();
      return;
    }
    if (_visible) {
      _hideTimer?.cancel();
      setState(() => _visible = false);
    } else {
      _show();
    }
  }

  void _openMenu([PlayerMenuPage page = PlayerMenuPage.root]) {
    _hideTimer?.cancel();
    setState(() {
      _menu = true;
      _menuPage = page;
      _visible = true;
    });
  }

  void _closeMenu() {
    if (!_menu) return;
    setState(() => _menu = false);
    _scheduleHide();
    // Télécommande : le focus revient sur les boutons du lecteur.
    if (OFDevice.tv) _playFocus.requestFocus();
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
      _menu = false;
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
    if (_locked || _menu) return;
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
    if (_locked || _menu) return;
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

  // ------------------------------------------------------------ Actions

  Future<void> _searchSubtitles() async {
    setState(() => _menu = false);
    _hideTimer?.cancel();
    await showOFSheet<void>(context, builder: (_) => SubtitleSearchSheet(controller: widget.controller));
    _scheduleHide();
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
    final metrics = _Metrics.of(context);
    return Focus(
      focusNode: _keys,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Listener(
        // Tout toucher réveille le suivi du verre natif (boutons, menu, barre de progression).
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => NativeGlassScope.maybeOf(context)?.wake(),
        onPointerMove: (_) => NativeGlassScope.maybeOf(context)?.wake(),
        onPointerUp: (_) => NativeGlassScope.maybeOf(context)?.wake(),
        child: MouseRegion(
          // Ordinateur : curseur masqué avec les contrôles.
          cursor: OFDevice.desktop && !_visible ? SystemMouseCursors.none : MouseCursor.defer,
          onHover: OFDevice.desktop ? (_) => _onHover() : null,
          child: BackdropGroup(
            child: StreamBuilder<PlayerSnapshot>(
              stream: widget.engine.snapshots,
              initialData: widget.engine.snapshot,
              builder: (context, snap) {
                final s = snap.data ?? const PlayerSnapshot();
                final showSpinner = s.buffering || s.status == PlaybackStatus.loading || ui.reloading;
                final padding = MediaQuery.paddingOf(context);
                final overlayBottom = padding.bottom + (_visible ? metrics.bottomBarClearance : OFSpacing.xxl);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Couche gestes SOUS les contrôles : les boutons reçoivent leurs taps
                    // immédiatement (sinon le détecteur de double-tap les retarde de 300 ms),
                    // les zones vides laissent passer vers cette couche.
                    // Ordinateur : clic = lecture/pause, double-clic = plein écran, molette = volume.
                    if (OFDevice.desktop)
                      Listener(
                        onPointerSignal: (e) {
                          if (e is PointerScrollEvent) _changeVolume(e.scrollDelta.dy < 0 ? 0.05 : -0.05);
                        },
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (_menu) return _closeMenu();
                            unawaited(widget.controller.togglePlay());
                            _show();
                          },
                          onDoubleTap: _toggleFullscreen,
                        ),
                      )
                    else
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
                            icon: _level == _Level.brightness
                                ? Icons.brightness_6_rounded
                                : (_volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                            value: _level == _Level.brightness ? _brightness : _volume,
                          ),
                        ),
                      ),
                    if (showSpinner && !_visible) IgnorePointer(child: Center(child: OFLoader.glass())),
                    IgnorePointer(
                      key: const ValueKey('controles'),
                      ignoring: !_visible || _locked,
                      child: AnimatedOpacity(
                        opacity: _visible && !_locked ? 1 : 0,
                        duration: motion.standard,
                        curve: OFMotion.standardCurve,
                        child: OFDevice.tv
                            ? TvPlayerControls(
                                snapshot: s,
                                scrubbing: _scrubbing,
                                showSpinner: showSpinner,
                                debug: _debug,
                                ui: ui,
                                engine: widget.engine,
                                fit: widget.fit,
                                playFocus: _playFocus,
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
                                onMenu: _openMenu,
                                onCycleFit: () {
                                  widget.onCycleFit();
                                  _show();
                                },
                              )
                            : (_visible && !_locked) || motion.enabled
                            ? _ControlsLayer(
                                metrics: metrics,
                                snapshot: s,
                                scrubbing: _scrubbing,
                                showSpinner: showSpinner,
                                debug: _debug,
                                menuOpen: _menu,
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
                                onSettings: () => _menu ? _closeMenu() : _openMenu(),
                                // TV : pas de Picture-in-Picture (lecture en plein écran).
                                onPictureInPicture:
                                    widget.engine.capabilities.pictureInPicture && !OFDevice.tv && !OFDevice.desktop
                                    ? _pictureInPicture
                                    : null,
                                onCycleFit: () {
                                  widget.onCycleFit();
                                  _show();
                                },
                                onToggleDebug: () => setState(() => _debug = !_debug),
                                playFocus: _playFocus,
                                onFullscreen: OFDevice.desktop ? _toggleFullscreen : null,
                                fullscreen: _fullscreen,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    // Menu Réglages : ancré sous son bouton, se déploie depuis le coin.
                    // TV : panneau latéral à droite, sur toute la hauteur.
                    Positioned(
                      key: const ValueKey('menu'),
                      top: OFDevice.tv ? TvPlayerControls.safeY : padding.top + metrics.menuTop,
                      right: OFDevice.tv ? TvPlayerControls.safeX - OFSpacing.lg : padding.right + metrics.edge,
                      child: AnimatedSwitcher(
                        duration: motion.standard,
                        switchInCurve: OFMotion.emphasizedCurve,
                        switchOutCurve: OFMotion.standardCurve,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween(begin: 0.85, end: 1.0).animate(animation),
                            alignment: Alignment.topRight,
                            child: child,
                          ),
                        ),
                        child: _menu && !_locked
                            // Portée de focus propre : les flèches restent dans le menu ouvert.
                            ? FocusScope(
                                key: ValueKey('menu-${_menuPage.name}'),
                                child: PlayerSettingsMenu(
                                  initialPage: _menuPage,
                                  controller: widget.controller,
                                  engine: widget.engine,
                                  debug: _debug,
                                  onDismiss: _closeMenu,
                                  onLock: _lock,
                                  onSearchSubtitles: _searchSubtitles,
                                  // Au-dessus de la barre de progression, qu'il ne recouvre jamais.
                                  maxHeight: OFDevice.tv
                                      ? MediaQuery.sizeOf(context).height - 2 * TvPlayerControls.safeY
                                      : MediaQuery.sizeOf(context).height -
                                            padding.vertical -
                                            metrics.menuTop -
                                            metrics.bottomBarClearance,
                                  onToggleDebug: () => setState(() => _debug = !_debug),
                                ),
                              )
                            : const SizedBox.shrink(key: ValueKey('ferme')),
                      ),
                    ),
                    // « Passer l'intro » : visible même contrôles masqués (mais pas verrouillé).
                    if (ui.segment != null && !_locked && !ui.upNext && !_menu)
                      Positioned(
                        right: padding.right + metrics.edge,
                        bottom: overlayBottom,
                        child: FadeSlideIn(
                          key: ValueKey(ui.segment),
                          axis: Axis.horizontal,
                          offset: 32,
                          child: SkipSegmentButton(segment: ui.segment!, onSkip: widget.controller.skipSegment),
                        ),
                      ),
                    if (ui.upNext && next != null && !_locked && !_menu)
                      Positioned(
                        right: padding.right + metrics.edge,
                        bottom: overlayBottom,
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
                        bottom: padding.bottom + OFSpacing.xxl,
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: _showUnlock ? 1 : 0,
                            duration: motion.standard,
                            child: IgnorePointer(
                              ignoring: !_showUnlock,
                              child: OFGlassButton(
                                label: 'Déverrouiller',
                                icon: Icons.lock_open_rounded,
                                iconSize: 22,
                                size: 48,
                                showLabel: true,
                                onPressed: _unlock,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Tailles du lecteur selon l'appareil : tout grandit un peu sur tablette.
class _Metrics {
  const _Metrics({required this.tablet});

  factory _Metrics.of(BuildContext context) => _Metrics(tablet: OFDevice.large(context));

  final bool tablet;

  double get edge => tablet ? OFSpacing.xl : OFSpacing.lg;
  double get button => tablet ? 50 : 44;
  double get skip => tablet ? 68 : 58;
  double get play => tablet ? 92 : 76;
  double get gap => tablet ? 44 : 32;

  /// Haut du menu Réglages (sous la barre du haut).
  double get menuTop => OFSpacing.sm + button + OFSpacing.sm;

  /// Hauteur réservée à la barre de progression quand elle est visible.
  double get bottomBarClearance => tablet ? 104 : 92;
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
      child: LiquidGlass(
        padding: const EdgeInsets.symmetric(horizontal: OFSpacing.lg, vertical: OFSpacing.md),
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
    required this.metrics,
    required this.snapshot,
    required this.scrubbing,
    required this.showSpinner,
    required this.debug,
    required this.menuOpen,
    required this.ui,
    required this.engine,
    required this.fit,
    required this.onClose,
    required this.onPlayPause,
    required this.onSkip,
    required this.onScrubStart,
    required this.onScrub,
    required this.onScrubEnd,
    required this.onSettings,
    required this.onPictureInPicture,
    required this.onCycleFit,
    required this.onToggleDebug,
    required this.playFocus,
    this.onFullscreen,
    this.fullscreen = false,
  });

  /// Ordinateur : plein écran de la fenêtre.
  final VoidCallback? onFullscreen;
  final bool fullscreen;

  /// Focus du bouton lecture/pause (télécommande).
  final FocusNode playFocus;

  final _Metrics metrics;
  final PlayerSnapshot snapshot;
  final Duration? scrubbing;
  final bool showSpinner;
  final bool debug;
  final bool menuOpen;
  final PlayerUiState ui;
  final PlaybackEngine engine;
  final BoxFit fit;
  final VoidCallback onClose;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSkip;
  final ValueChanged<Duration> onScrubStart;
  final ValueChanged<Duration> onScrub;
  final ValueChanged<Duration> onScrubEnd;
  final VoidCallback onSettings;
  final VoidCallback? onPictureInPicture;
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
    final m = metrics;
    final times = OFTypography.caption.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Voiles haut et bas, discrets : le verre assure déjà la lisibilité.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x80000000), Color(0x00000000), Color(0x00000000), Color(0x99000000)],
                stops: [0, 0.25, 0.65, 1],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(m.edge, OFSpacing.sm, m.edge, OFSpacing.md),
            child: Column(
              children: [
                Row(
                  children: [
                    OFGlassButton(
                      icon: Icons.close_rounded,
                      label: 'Fermer le lecteur',
                      size: m.button,
                      iconSize: m.button * 0.5,
                      onPressed: onClose,
                    ),
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
                    const SizedBox(width: OFSpacing.md),
                    _GlassCluster(
                      height: m.button,
                      children: [
                        if (engine.capabilities.airPlay) AirPlayButton(size: m.button),
                        if (onPictureInPicture != null)
                          _BareButton(
                            icon: Icons.picture_in_picture_alt_rounded,
                            label: 'Picture-in-Picture',
                            size: m.button,
                            onTap: onPictureInPicture!,
                          ),
                        _BareButton(icon: fitIcon, label: fitLabel, size: m.button, onTap: onCycleFit),
                        if (onFullscreen != null)
                          _BareButton(
                            icon: fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                            label: fullscreen ? 'Quitter le plein écran' : 'Plein écran',
                            size: m.button,
                            onTap: onFullscreen!,
                          ),
                        _BareButton(
                          icon: menuOpen ? Icons.close_rounded : Icons.tune_rounded,
                          label: 'Réglages',
                          size: m.button,
                          active: menuOpen,
                          onTap: onSettings,
                        ),
                      ],
                    ),
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
                    _PlainButton(
                      icon: Icons.replay_10_rounded,
                      label: 'Reculer de 10 secondes',
                      size: m.skip,
                      iconSize: m.skip * 0.62,
                      onPressed: () => onSkip(const Duration(seconds: -10)),
                    ),
                    SizedBox(width: m.gap),
                    _PlainButton(
                      icon: snapshot.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      label: snapshot.playing ? 'Pause' : 'Lecture',
                      size: m.play,
                      iconSize: m.play * 0.72,
                      onPressed: onPlayPause,
                      focusNode: playFocus,
                      autofocus: OFDevice.tv,
                      child: showSpinner ? OFLoader(size: m.play * 0.42) : null,
                    ),
                    SizedBox(width: m.gap),
                    _PlainButton(
                      icon: Icons.forward_10_rounded,
                      label: 'Avancer de 10 secondes',
                      size: m.skip,
                      iconSize: m.skip * 0.62,
                      onPressed: () => onSkip(const Duration(seconds: 10)),
                    ),
                  ],
                ),
                const Spacer(),
                if (chapter != null && scrubbing == null)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: OFSpacing.xxs),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        chapter.name,
                        style: OFTypography.caption.copyWith(color: OFColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                // Barre de progression façon Infuse : la piste est elle-même en verre et
                // la lecture la remplit de blanc ; temps écoulé et restant dessous.
                Scrubber(
                  position: position,
                  duration: duration,
                  buffered: snapshot.buffered,
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    children: [
                      Text(MediaFormat.clock(position), style: times.copyWith(color: OFColors.textSecondary)),
                      const Spacer(),
                      Text(
                        '-${MediaFormat.clock(duration > position ? duration - position : Duration.zero)}',
                        style: times.copyWith(color: OFColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Groupe de boutons dans une même pilule de verre (AirPlay, PiP, format, réglages).
class _GlassCluster extends StatelessWidget {
  const _GlassCluster({required this.children, required this.height});

  final List<Widget> children;
  final double height;

  @override
  Widget build(BuildContext context) => LiquidGlass(
    padding: const EdgeInsets.symmetric(horizontal: OFSpacing.xs),
    child: SizedBox(
      height: height,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    ),
  );
}

/// Bouton icône sans fond propre (posé dans un [_GlassCluster]).
class _BareButton extends StatefulWidget {
  const _BareButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.size,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  final bool active;

  @override
  State<_BareButton> createState() => _BareButtonState();
}

class _BareButtonState extends State<_BareButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (v != _pressed) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final motion = OFMotion.of(context);
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: TvFocusable(
        onSelect: widget.onTap,
        scale: 1.15,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          // Verre interactif : le bouton gonfle et s'illumine sous le doigt.
          child: GlassPress(
            scale: 1.18,
            child: SizedBox.square(
              dimension: widget.size,
              child: Center(
                child: AnimatedContainer(
                  duration: motion.standard,
                  curve: OFMotion.standardCurve,
                  width: widget.size - 8,
                  height: widget.size - 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.active ? const Color(0x33FFFFFF) : const Color(0x00FFFFFF),
                  ),
                  child: AnimatedSwitcher(
                    duration: motion.fast,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: RotationTransition(turns: Tween(begin: 0.85, end: 1.0).animate(a), child: child),
                    ),
                    child: Icon(
                      widget.icon,
                      key: ValueKey(widget.icon),
                      size: widget.size * 0.48,
                      color: OFColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barre de progression façon Infuse : une piste en verre que la lecture remplit de
/// blanc (le tampon en blanc léger), sans curseur ni couleur d'accent. Elle s'épaissit
/// pendant le glissé, avec une prévisualisation (vignette trickplay ou heure) au-dessus
/// du doigt. Toucher = aller directement à ce point.
class Scrubber extends StatefulWidget {
  const Scrubber({
    super.key,
    required this.position,
    required this.duration,
    required this.buffered,
    required this.onStart,
    required this.onChanged,
    required this.onEnd,
    this.scrubbing = false,
    this.preview,
  });

  final Duration position;
  final Duration duration;
  final Duration buffered;
  final bool scrubbing;
  final Widget? preview;
  final ValueChanged<Duration> onStart;
  final ValueChanged<Duration> onChanged;
  final ValueChanged<Duration> onEnd;

  static const _touchHeight = 36.0;

  @override
  State<Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<Scrubber> {
  Duration _last = Duration.zero;

  /// Focalisée à la télécommande : barre épaissie, ◀ ▶ reculent ou avancent.
  bool _focused = false;

  /// Recherche à la télécommande (comme sur l'Apple TV) : ◀ ▶ déplacent un curseur
  /// d'aperçu (vignettes), de plus en plus vite si la touche reste enfoncée ; la lecture
  /// saute à la position choisie à l'appui sur OK ou une fraction de seconde après.
  Duration? _keyTarget;
  Timer? _keyCommit;
  int _repeats = 0;

  @override
  void dispose() {
    _keyCommit?.cancel();
    super.dispose();
  }

  void _commitKeys() {
    _keyCommit?.cancel();
    final target = _keyTarget;
    _keyTarget = null;
    _repeats = 0;
    if (target != null) widget.onEnd(target);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (_total <= 0) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (_keyTarget != null && (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter)) {
      if (event is KeyDownEvent) _commitKeys();
      return KeyEventResult.handled;
    }
    final left = key == LogicalKeyboardKey.arrowLeft;
    if (!left && key != LogicalKeyboardKey.arrowRight) return KeyEventResult.ignored;
    if (event is KeyUpEvent) {
      _keyCommit?.cancel();
      _keyCommit = Timer(const Duration(milliseconds: 900), _commitKeys);
      return KeyEventResult.handled;
    }
    _keyCommit?.cancel();
    _repeats = event is KeyRepeatEvent ? _repeats + 1 : 0;
    final step = Duration(seconds: _repeats > 20 ? 120 : (_repeats > 6 ? 60 : (_repeats > 0 ? 30 : 10)));
    final from = _keyTarget ?? widget.position;
    var target = from + (left ? -step : step);
    if (target < Duration.zero) target = Duration.zero;
    if (target > widget.duration) target = widget.duration;
    if (_keyTarget == null) {
      widget.onStart(target);
    } else {
      widget.onChanged(target);
    }
    _keyTarget = target;
    return KeyEventResult.handled;
  }

  int get _total => widget.duration.inMilliseconds;

  double _fraction(Duration d) => _total <= 0 ? 0 : (d.inMilliseconds / _total).clamp(0.0, 1.0);

  Duration _at(double dx, double width) =>
      Duration(milliseconds: (width <= 0 ? 0 : (dx / width).clamp(0.0, 1.0) * _total).round());

  void _start(Duration d) {
    HapticFeedback.selectionClick();
    _last = d;
    widget.onStart(d);
  }

  void _update(Duration d) {
    _last = d;
    widget.onChanged(d);
  }

  void _end() => widget.onEnd(_last);

  @override
  Widget build(BuildContext context) {
    final motion = OFMotion.of(context);
    final enabled = _total > 0;
    final played = _fraction(widget.position);
    final buffered = _fraction(widget.buffered);
    final thickness = widget.scrubbing || _focused ? 13.0 : 8.0;
    const step = Duration(seconds: 10);

    Widget fill(double fraction, Color color) => Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fraction,
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.all(Radius.circular(OFRadius.pill))),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Semantics(
          slider: true,
          label: 'Position de lecture',
          value: MediaFormat.clock(widget.position),
          increasedValue: MediaFormat.clock(widget.position + step),
          decreasedValue: MediaFormat.clock(widget.position > step ? widget.position - step : Duration.zero),
          onIncrease: enabled ? () => widget.onEnd(widget.position + step) : null,
          onDecrease: enabled ? () => widget.onEnd(widget.position - step) : null,
          child: TvFocusable(
            ring: false,
            scale: 1,
            onKeyEvent: _onKey,
            onFocusChange: (f) {
              if (!f && _keyTarget != null) _commitKeys();
              setState(() => _focused = f);
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: enabled ? (d) => _start(_at(d.localPosition.dx, width)) : null,
              onHorizontalDragUpdate: enabled ? (d) => _update(_at(d.localPosition.dx, width)) : null,
              onHorizontalDragEnd: enabled ? (_) => _end() : null,
              onHorizontalDragCancel: enabled ? _end : null,
              onTapUp: enabled
                  ? (d) {
                      _start(_at(d.localPosition.dx, width));
                      _end();
                    }
                  : null,
              child: SizedBox(
                height: Scrubber._touchHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: AnimatedContainer(
                        duration: motion.fast,
                        curve: OFMotion.standardCurve,
                        height: thickness,
                        child: LiquidGlass(
                          shade: 0,
                          rim: false,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [fill(buffered, const Color(0x33FFFFFF)), fill(played, const Color(0xF2FFFFFF))],
                          ),
                        ),
                      ),
                    ),
                    if (widget.preview != null)
                      Positioned(
                        bottom: Scrubber._touchHeight + 4,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Align(
                            // Centré sur le doigt, sans déborder de l'écran.
                            alignment: Alignment(played * 2 - 1, 1),
                            child: widget.preview,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bouton central du lecteur (lecture/pause, ±10 s) : icône seule, sans verre, avec
/// une ombre douce pour rester lisible sur une image claire (comme Infuse).
class _PlainButton extends StatefulWidget {
  const _PlainButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.size,
    required this.iconSize,
    this.child,
    this.focusNode,
    this.autofocus = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Contenu à la place de l'icône (indicateur de chargement).
  final Widget? child;

  @override
  State<_PlainButton> createState() => _PlainButtonState();
}

class _PlainButtonState extends State<_PlainButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (v != _pressed) setState(() => _pressed = v);
  }

  static const _shadow = [Shadow(color: Color(0x73000000), blurRadius: 16)];

  @override
  Widget build(BuildContext context) {
    final motion = OFMotion.of(context);
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      // Télécommande : cercle lumineux autour de l'icône focalisée.
      child: TvFocusable(
        onSelect: widget.onPressed,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        scale: 1.12,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onPressed();
          },
          child: AnimatedScale(
            scale: _pressed ? 0.86 : 1,
            duration: motion.fast,
            curve: OFMotion.fastCurve,
            child: SizedBox.square(
              dimension: widget.size,
              child: Center(
                child: AnimatedSwitcher(
                  duration: motion.fast,
                  child:
                      widget.child ??
                      Icon(
                        widget.icon,
                        key: ValueKey(widget.icon),
                        size: widget.iconSize,
                        color: OFColors.textPrimary,
                        shadows: _shadow,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
