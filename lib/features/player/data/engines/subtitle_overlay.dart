import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/playback_engine.dart';
import '../../domain/subtitle_cues.dart';

/// Horloge de lecture remontée par le moteur (toutes les ~250 ms) : l'overlay
/// l'extrapole à chaque image pour des sous-titres synchronisés à la frame près.
class PlaybackClock {
  const PlaybackClock(this.position, {this.playing = false, this.rate = 1, required this.at});

  final Duration position;
  final bool playing;
  final double rate;

  /// Instant de la mesure (horloge monotone, microsecondes).
  final int at;

  Duration estimate(int now) {
    if (!playing) return position;
    final elapsed = ((now - at) * rate).round();
    return position + Duration(microseconds: elapsed.clamp(0, 2000000));
  }
}

final _monotonic = Stopwatch()..start();

/// Horloge monotone partagée par le moteur et l'overlay.
int monotonicMicros() => _monotonic.elapsedMicroseconds;

/// Sous-titres texte dessinés au-dessus d'une vidéo native, selon le style choisi
/// (taille, couleur, fond, marge) : même rendu sur iOS et Android.
class SubtitleOverlay extends StatefulWidget {
  const SubtitleOverlay({
    super.key,
    required this.track,
    required this.clock,
    required this.style,
    required this.delay,
  });

  final ValueListenable<CueTrack?> track;
  final ValueListenable<PlaybackClock> clock;
  final ValueListenable<SubtitleStyle> style;
  final ValueListenable<Duration> delay;

  @override
  State<SubtitleOverlay> createState() => _SubtitleOverlayState();
}

class _SubtitleOverlayState extends State<SubtitleOverlay> {
  /// Réveil programmé au prochain changement de texte (début ou fin de réplique) :
  /// aucune image calculée entre deux répliques (une horloge à chaque image gardait
  /// le GPU actif pendant tout le film).
  Timer? _timer;
  String? _text;

  @override
  void initState() {
    super.initState();
    for (final l in [widget.track, widget.clock, widget.style, widget.delay]) {
      l.addListener(_onChange);
    }
    _text = _currentText();
    _style = widget.style.value;
    _schedule();
  }

  @override
  void dispose() {
    for (final l in [widget.track, widget.clock, widget.style, widget.delay]) {
      l.removeListener(_onChange);
    }
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    final clock = widget.clock.value;
    final track = widget.track.value;
    if (!clock.playing || track == null || clock.rate <= 0) return;
    final position = clock.estimate(monotonicMicros()) - widget.delay.value;
    final next = track.nextChangeAfter(position);
    if (next == null) return;
    final wait = Duration(microseconds: ((next - position).inMicroseconds / clock.rate).round() + 2000);
    _timer = Timer(wait, () {
      _refresh();
      _schedule();
    });
  }

  SubtitleStyle? _style;

  void _onChange() {
    // L'horloge change 4 fois par seconde : reconstruction seulement si le texte ou le style change.
    final styleChanged = !identical(_style, widget.style.value);
    _style = widget.style.value;
    _refresh(force: styleChanged);
    _schedule();
  }

  String? _currentText() {
    final position = widget.clock.value.estimate(monotonicMicros()) - widget.delay.value;
    return widget.track.value?.textAt(position);
  }

  void _refresh({bool force = false}) {
    final text = _currentText();
    // Reconstruction seulement quand le texte change (pas à chaque image).
    if (mounted && (force || text != _text)) setState(() => _text = text);
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    if (text == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) => SubtitleText(text: text, style: widget.style.value, height: c.maxHeight),
      ),
    );
  }
}

/// Texte d'un sous-titre positionné en bas de l'image.
class SubtitleText extends StatelessWidget {
  const SubtitleText({super.key, required this.text, required this.style, required this.height});

  final String text;
  final SubtitleStyle style;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Taille proportionnelle à la hauteur de l'image (comme mpv) : lisible en portrait comme en paysage.
    final fontSize = (height * 0.052 * style.scale).clamp(12.0, 64.0);
    final outline = switch (style.background) {
      SubtitleBackground.none => [
        for (final (dx, dy) in const [(-1.5, -1.5), (1.5, -1.5), (-1.5, 1.5), (1.5, 1.5), (0.0, 2.0)])
          Shadow(offset: Offset(dx, dy), blurRadius: 1.5, color: const Color(0xE6000000)),
      ],
      SubtitleBackground.shadow => const [Shadow(offset: Offset(2, 2), blurRadius: 4, color: Color(0xCC000000))],
      SubtitleBackground.box => const <Shadow>[],
    };
    final label = Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: fontSize,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: style.color,
        shadows: outline,
      ),
    );
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, height * style.bottomMargin),
        child: style.background == SubtitleBackground.box
            ? DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0x99000000),
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), child: label),
              )
            : label,
      ),
    );
  }
}
