import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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

class _SubtitleOverlayState extends State<SubtitleOverlay> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => _refresh());
  String? _text;

  @override
  void initState() {
    super.initState();
    for (final l in [widget.track, widget.clock, widget.style, widget.delay]) {
      l.addListener(_onChange);
    }
    _text = _currentText();
    _syncTicker();
  }

  @override
  void dispose() {
    for (final l in [widget.track, widget.clock, widget.style, widget.delay]) {
      l.removeListener(_onChange);
    }
    _ticker.dispose();
    super.dispose();
  }

  /// Le ticker ne tourne que pendant la lecture et s'il y a des sous-titres.
  void _syncTicker() {
    final active = widget.clock.value.playing && widget.track.value != null;
    if (active && !_ticker.isActive) _ticker.start();
    if (!active && _ticker.isActive) _ticker.stop();
  }

  void _onChange() {
    _syncTicker();
    _refresh(force: true);
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
