import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/media/formatters.dart';
import '../../../core/providers.dart';
import '../domain/engine_selector.dart';
import '../domain/playback_engine.dart';
import '../domain/playback_extras.dart';
import '../domain/playback_plan.dart';
import 'player_controller.dart';
import 'player_sheets.dart' show DelayStepper;

enum PlayerMenuPage { root, audio, subtitles, subtitleStyle, chapters, speed, sync, engine }

/// Menu « Réglages » du lecteur : panneau en verre ancré sous son bouton.
///
/// La racine résume chaque réglage (piste audio, sous-titres, vitesse…) ; un toucher
/// ouvre le sous-menu correspondant. Choisir une piste, une vitesse, un chapitre ou
/// un moteur referme le menu ; les réglages fins (décalages, apparence) le gardent ouvert.
class PlayerSettingsMenu extends ConsumerStatefulWidget {
  const PlayerSettingsMenu({
    super.key,
    required this.controller,
    required this.engine,
    required this.onDismiss,
    required this.onLock,
    required this.onSearchSubtitles,
    required this.onToggleDebug,
    required this.debug,
    this.initialPage = PlayerMenuPage.root,
    this.maxHeight,
  });

  final PlayerController controller;
  final PlaybackEngine engine;
  final VoidCallback onDismiss;
  final VoidCallback onLock;
  final VoidCallback? onSearchSubtitles;
  final VoidCallback onToggleDebug;
  final bool debug;
  final PlayerMenuPage initialPage;

  /// Hauteur disponible (le menu défile au-delà) ; par défaut, presque tout l'écran.
  final double? maxHeight;

  static const width = 330.0;

  @override
  ConsumerState<PlayerSettingsMenu> createState() => _PlayerSettingsMenuState();
}

class _PlayerSettingsMenuState extends ConsumerState<PlayerSettingsMenu> {
  late PlayerMenuPage _page = widget.initialPage;
  bool _forward = true;

  static PlayerMenuPage _parent(PlayerMenuPage p) =>
      p == PlayerMenuPage.subtitleStyle ? PlayerMenuPage.subtitles : PlayerMenuPage.root;

  void _open(PlayerMenuPage page) {
    HapticFeedback.selectionClick();
    setState(() {
      _forward = true;
      _page = page;
    });
  }

  void _back() {
    HapticFeedback.selectionClick();
    setState(() {
      _forward = false;
      _page = _parent(_page);
    });
  }

  /// Choix définitif : applique puis referme le menu.
  void _choose(Future<void> Function() action) {
    HapticFeedback.selectionClick();
    unawaited(action());
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerControllerProvider(widget.controller.args));
    final plan = state.plan;
    if (plan == null) return const SizedBox.shrink();
    final motion = OFMotion.of(context);
    final mq = MediaQuery.of(context);
    final maxHeight = (widget.maxHeight ?? mq.size.height - mq.padding.vertical - 96).clamp(160.0, 620.0);

    return LiquidGlass(
      borderRadius: const BorderRadius.all(Radius.circular(26)),
      sigma: 30,
      shade: 0.5,
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: PlayerSettingsMenu.width,
          child: AnimatedSize(
            duration: motion.standard,
            curve: OFMotion.standardCurve,
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: StreamBuilder<PlayerSnapshot>(
                stream: widget.engine.snapshots,
                initialData: widget.engine.snapshot,
                builder: (context, snap) {
                  final s = snap.data ?? const PlayerSnapshot();
                  return AnimatedSwitcher(
                    duration: motion.standard,
                    switchInCurve: OFMotion.standardCurve,
                    switchOutCurve: OFMotion.standardCurve,
                    layoutBuilder: (current, previous) =>
                        Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                    transitionBuilder: (child, animation) {
                      final incoming = child.key == ValueKey(_page);
                      final dx = (_forward ? 1 : -1) * (incoming ? 0.15 : -0.15);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(key: ValueKey(_page), child: _buildPage(state, plan, s)),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPage(PlayerUiState state, PlaybackPlan plan, PlayerSnapshot s) {
    final c = widget.controller;
    final caps = widget.engine.capabilities;
    return switch (_page) {
      PlayerMenuPage.root => _MenuPageView(
        children: [
          if (plan.audioTracks.isNotEmpty)
            _MenuRow(
              icon: Icons.graphic_eq_rounded,
              label: 'Audio',
              value: plan.currentAudio?.label ?? '—',
              onTap: () => _open(PlayerMenuPage.audio),
            ),
          _MenuRow(
            icon: Icons.subtitles_outlined,
            label: 'Sous-titres',
            value: plan.currentSubtitle?.label ?? 'Désactivés',
            onTap: () => _open(PlayerMenuPage.subtitles),
          ),
          if (state.extras.chapters.isNotEmpty)
            _MenuRow(
              icon: Icons.format_list_bulleted_rounded,
              label: 'Chapitres',
              value: state.extras.chapterAt(s.position)?.name,
              onTap: () => _open(PlayerMenuPage.chapters),
            ),
          if (caps.playbackSpeed)
            _MenuRow(
              icon: Icons.speed_rounded,
              label: 'Vitesse',
              value: _rateLabel(s.rate),
              onTap: () => _open(PlayerMenuPage.speed),
            ),
          if (caps.subtitleDelay || caps.audioDelay)
            _MenuRow(
              icon: Icons.av_timer_rounded,
              label: 'Synchronisation',
              value: state.subtitleDelay == Duration.zero && state.audioDelay == Duration.zero
                  ? 'Aucun décalage'
                  : 'Ajustée',
              onTap: () => _open(PlayerMenuPage.sync),
            ),
          _MenuRow(
            icon: Icons.memory_rounded,
            label: 'Moteur de lecture',
            value: '${_preferenceLabel(state.preference ?? EnginePreference.auto)} · ${widget.engine.name}',
            onTap: () => _open(PlayerMenuPage.engine),
          ),
          const _MenuDivider(),
          _MenuRow(
            icon: Icons.lock_outline_rounded,
            label: 'Verrouiller l’écran',
            chevron: false,
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onLock();
            },
          ),
          _MenuRow(
            icon: Icons.info_outline_rounded,
            label: 'Infos techniques',
            chevron: false,
            selected: widget.debug,
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onToggleDebug();
            },
          ),
        ],
      ),
      PlayerMenuPage.audio => _MenuPageView(
        title: 'Audio',
        onBack: _back,
        children: [
          for (final t in plan.audioTracks)
            _MenuRow(
              label: t.label,
              detail: _trackDetail(t),
              selected: t.index == plan.audioIndex,
              chevron: false,
              onTap: () => _choose(() => c.selectAudio(t)),
            ),
        ],
      ),
      PlayerMenuPage.subtitles => _MenuPageView(
        title: 'Sous-titres',
        onBack: _back,
        children: [
          _MenuRow(
            label: 'Désactivés',
            selected: plan.subtitleIndex == null,
            chevron: false,
            onTap: () => _choose(() => c.selectSubtitle(null)),
          ),
          for (final t in plan.subtitleTracks)
            _MenuRow(
              label: t.label,
              detail: _trackDetail(t),
              selected: t.index == plan.subtitleIndex,
              chevron: false,
              onTap: () => _choose(() => c.selectSubtitle(t)),
            ),
          if (widget.onSearchSubtitles != null || caps.subtitleStyling) const _MenuDivider(),
          if (widget.onSearchSubtitles != null)
            _MenuRow(
              icon: Icons.travel_explore_rounded,
              label: 'Rechercher en ligne…',
              chevron: false,
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onSearchSubtitles!();
              },
            ),
          if (caps.subtitleStyling)
            _MenuRow(
              icon: Icons.format_size_rounded,
              label: 'Apparence',
              value: _scaleLabel(state.subtitleStyle.scale),
              onTap: () => _open(PlayerMenuPage.subtitleStyle),
            ),
        ],
      ),
      PlayerMenuPage.subtitleStyle => _MenuPageView(
        title: 'Apparence des sous-titres',
        onBack: _back,
        children: [
          const _MenuSection('Taille'),
          for (final v in const [0.8, 1.0, 1.25, 1.5])
            _MenuRow(
              label: _scaleLabel(v),
              selected: state.subtitleStyle.scale == v,
              chevron: false,
              onTap: () {
                HapticFeedback.selectionClick();
                unawaited(c.setSubtitleStyle(state.subtitleStyle.copyWith(scale: v)));
              },
            ),
          const _MenuSection('Fond'),
          for (final v in SubtitleBackground.values)
            _MenuRow(
              label: switch (v) {
                SubtitleBackground.none => 'Contour',
                SubtitleBackground.shadow => 'Ombre',
                SubtitleBackground.box => 'Bandeau',
              },
              selected: state.subtitleStyle.background == v,
              chevron: false,
              onTap: () {
                HapticFeedback.selectionClick();
                unawaited(c.setSubtitleStyle(state.subtitleStyle.copyWith(background: v)));
              },
            ),
        ],
      ),
      PlayerMenuPage.chapters => _MenuPageView(
        title: 'Chapitres',
        onBack: _back,
        children: [
          for (final ch in state.extras.chapters)
            _ChapterRow(
              itemId: plan.itemId,
              chapter: ch,
              current: identical(ch, state.extras.chapterAt(s.position)),
              onTap: () => _choose(() => c.seek(ch.start)),
            ),
        ],
      ),
      PlayerMenuPage.speed => _MenuPageView(
        title: 'Vitesse',
        onBack: _back,
        children: [
          for (final v in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
            _MenuRow(
              label: _rateLabel(v),
              selected: (s.rate - v).abs() < 0.01,
              chevron: false,
              onTap: () => _choose(() => c.setRate(v)),
            ),
        ],
      ),
      PlayerMenuPage.sync => _MenuPageView(
        title: 'Synchronisation',
        onBack: _back,
        children: [
          if (caps.subtitleDelay) ...[
            const _MenuSection('Décalage des sous-titres'),
            DelayStepper(
              value: state.subtitleDelay,
              onChanged: c.setSubtitleDelay,
              hint: 'Positif : les sous-titres apparaissent plus tard.',
            ),
          ],
          if (caps.audioDelay) ...[
            const _MenuSection('Décalage audio'),
            DelayStepper(value: state.audioDelay, onChanged: c.setAudioDelay, hint: 'Positif : le son est retardé.'),
          ],
          const SizedBox(height: OFSpacing.sm),
        ],
      ),
      PlayerMenuPage.engine => _MenuPageView(
        title: 'Moteur de lecture',
        onBack: _back,
        children: [
          for (final p in EnginePreference.values)
            _MenuRow(
              label: _preferenceLabel(p),
              detail: switch (p) {
                EnginePreference.auto => 'Le meilleur moteur pour chaque fichier',
                EnginePreference.native => 'AVPlayer / Media3 : HDR, PiP, AirPlay',
                EnginePreference.mpv => 'Lit presque tout, sous-titres stylés',
              },
              selected: (state.preference ?? EnginePreference.auto) == p,
              chevron: false,
              onTap: () => _choose(() => c.setEnginePreference(p)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(OFSpacing.lg, OFSpacing.sm, OFSpacing.lg, OFSpacing.sm),
            child: Text(
              'En cours : ${widget.engine.name} · ${plan.method.label}',
              style: OFTypography.caption.copyWith(color: OFColors.textTertiary),
            ),
          ),
        ],
      ),
    };
  }
}

String _rateLabel(double v) => v == 1 ? 'Normale' : '${v.toString().replaceAll('.', ',')}×';

String _scaleLabel(double v) => switch (v) {
  0.8 => 'Petite',
  1.0 => 'Normale',
  1.25 => 'Grande',
  _ => 'Très grande',
};

String _preferenceLabel(EnginePreference p) => switch (p) {
  EnginePreference.auto => 'Auto',
  EnginePreference.native => 'Natif',
  EnginePreference.mpv => 'mpv',
};

String? _trackDetail(MediaTrack t) {
  final parts = [
    if (t.isDefault) 'Par défaut',
    if (t.isForced) 'Forcés',
    if (t.isExternal) 'Externe',
    if (t.type == TrackType.subtitle && t.isBitmap) 'Image',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Une page du menu : en-tête (retour + titre) sauf à la racine, puis la liste.
class _MenuPageView extends StatelessWidget {
  const _MenuPageView({required this.children, this.title, this.onBack});

  final String? title;
  final VoidCallback? onBack;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(OFSpacing.xs, OFSpacing.xs, OFSpacing.lg, 0),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Retour',
                  excludeSemantics: true,
                  onTap: onBack,
                  child: InkResponse(
                    onTap: onBack,
                    radius: 22,
                    child: const SizedBox.square(
                      dimension: 44,
                      child: Icon(Icons.chevron_left_rounded, size: 28, color: OFColors.textPrimary),
                    ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title!, style: OFTypography.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
          ),
        if (title != null) const _MenuDivider(),
        Flexible(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(OFSpacing.sm), children: children),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    required this.onTap,
    this.icon,
    this.value,
    this.detail,
    this.selected = false,
    this.chevron = true,
  });

  final IconData? icon;
  final String label;

  /// Valeur actuelle, à droite (racine).
  final String? value;

  /// Seconde ligne discrète sous le libellé.
  final String? detail;
  final bool selected;
  final bool chevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final compact = MediaQuery.sizeOf(context).shortestSide < 600;
    return Semantics(
      button: true,
      selected: selected,
      label: [label, ?value].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        highlightColor: const Color(0x1AFFFFFF),
        splashColor: const Color(0x14FFFFFF),
        child: ConstrainedBox(
          // Téléphone en paysage : lignes plus serrées, la hauteur est comptée.
          constraints: BoxConstraints(minHeight: compact ? 42 : 48),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: OFSpacing.md,
              vertical: compact ? OFSpacing.xs + 1 : OFSpacing.sm,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 21, color: OFColors.textPrimary),
                  const SizedBox(width: OFSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: OFTypography.callout, maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (detail != null)
                        Text(
                          detail!,
                          style: OFTypography.caption.copyWith(color: OFColors.textTertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: OFSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Text(
                      value!,
                      style: OFTypography.callout.copyWith(color: OFColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (selected) ...[
                  const SizedBox(width: OFSpacing.sm),
                  Icon(Icons.check_rounded, size: 20, color: accent),
                ] else if (chevron) ...[
                  const SizedBox(width: OFSpacing.xs),
                  const Icon(Icons.chevron_right_rounded, size: 20, color: OFColors.textTertiary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapterRow extends ConsumerWidget {
  const _ChapterRow({required this.itemId, required this.chapter, required this.current, required this.onTap});

  final String itemId;
  final Chapter chapter;
  final bool current;
  final VoidCallback onTap;

  static const _thumb = 80.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(imageUrlBuilderProvider);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      selected: current,
      label: '${chapter.name}, ${MediaFormat.clock(chapter.start)}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        highlightColor: const Color(0x1AFFFFFF),
        child: Padding(
          padding: const EdgeInsets.all(OFSpacing.sm),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: OFRadius.smAll,
                child: SizedBox(
                  width: _thumb,
                  height: _thumb * 9 / 16,
                  child: chapter.imageTag == null
                      ? const ColoredBox(
                          color: Color(0x1AFFFFFF),
                          child: Icon(Icons.movie_outlined, size: 18, color: OFColors.textTertiary),
                        )
                      : OFImage(
                          url: images.chapterImage(
                            itemId,
                            chapter.index,
                            tag: chapter.imageTag,
                            logicalWidth: _thumb,
                            devicePixelRatio: dpr,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: OFSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.name,
                      style: OFTypography.callout.copyWith(color: current ? accent : OFColors.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      MediaFormat.clock(chapter.start),
                      style: OFTypography.caption.copyWith(
                        color: OFColors.textTertiary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              if (current) Icon(Icons.play_arrow_rounded, size: 20, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(OFSpacing.md, OFSpacing.md, OFSpacing.md, OFSpacing.xs),
    child: Text(
      text.toUpperCase(),
      style: OFTypography.caption.copyWith(color: OFColors.textTertiary, letterSpacing: 1.1),
    ),
  );
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: OFSpacing.md, vertical: OFSpacing.xs),
    child: SizedBox(height: 0.5, child: ColoredBox(color: Color(0x26FFFFFF))),
  );
}
