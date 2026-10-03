import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../device.dart';
import '../tokens.dart';

/// Élément atteignable à la télécommande (ou au clavier) : flèches pour y aller, OK pour
/// l'activer. Quand le focus vient de la télécommande, l'élément grossit légèrement et
/// s'entoure d'un liseré lumineux ; au toucher, rien ne change (téléphones inchangés).
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    super.key,
    required this.child,
    this.onSelect,
    this.borderRadius = const BorderRadius.all(Radius.circular(OFRadius.pill)),
    this.scale = 1.06,
    this.autofocus = false,
    this.focusNode,
    this.onKeyEvent,
    this.ring = true,
    this.onFocusChange,
  });

  final Widget child;
  final VoidCallback? onSelect;
  final BorderRadius borderRadius;
  final double scale;
  final bool autofocus;
  final FocusNode? focusNode;

  /// Touches propres à l'élément (ex. gauche/droite sur la barre de progression).
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;

  /// Liseré autour de l'élément (false : zoom seul, l'élément dessine lui-même son focus).
  final bool ring;
  final ValueChanged<bool>? onFocusChange;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    final motion = OFMotion.of(context);
    final select = widget.onSelect;
    final Widget child = AnimatedScale(
      scale: _highlighted ? widget.scale : 1,
      duration: motion.fast,
      curve: OFMotion.standardCurve,
      child: widget.ring
          ? AnimatedContainer(
              duration: motion.fast,
              foregroundDecoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                border: Border.all(
                  color: _highlighted ? const Color(0xE6FFFFFF) : const Color(0x00FFFFFF),
                  width: 2.5,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
              ),
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                boxShadow: [
                  if (_highlighted) const BoxShadow(color: Color(0x40FFFFFF), blurRadius: 24, spreadRadius: 1),
                ],
              ),
              child: widget.child,
            )
          : widget.child,
    );
    final detector = FocusableActionDetector(
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      enabled: select != null || widget.onKeyEvent != null,
      actions: {
        if (select != null)
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              HapticFeedback.selectionClick();
              select();
              return null;
            },
          ),
      },
      onShowFocusHighlight: (v) {
        if (v != _highlighted) setState(() => _highlighted = v);
      },
      onFocusChange: widget.onFocusChange,
      child: child,
    );
    // Les touches remontent du nœud focalisé vers ses ancêtres : le gestionnaire se place
    // au-dessus du détecteur.
    final onKey = widget.onKeyEvent;
    if (onKey == null) return detector;
    return Focus(onKeyEvent: onKey, skipTraversal: true, canRequestFocus: false, child: detector);
  }
}

/// Champ texte à la télécommande : le focus s'y pose sans ouvrir le clavier (sinon, il
/// surgit au simple passage) ; OK ouvre le clavier, ▲ ▼ quittent le champ (Flutter les
/// garde pour déplacer le curseur, ce qui y piégeait le focus). Hors TV : transparent.
///
/// [builder] reçoit le nœud de focus à donner au champ, `readOnly` (vrai tant que l'on
/// n'édite pas) et `done`, à appeler à la validation du clavier.
class TvTextEntry extends StatefulWidget {
  const TvTextEntry({super.key, required this.enabled, required this.builder, this.focusNode});

  /// Comportement TV actif (OFDevice.tv).
  final bool enabled;
  final FocusNode? focusNode;
  final Widget Function(BuildContext context, FocusNode node, bool readOnly, VoidCallback done) builder;

  @override
  State<TvTextEntry> createState() => _TvTextEntryState();
}

class _TvEditIntent extends Intent {
  const _TvEditIntent();
}

class _TvTextEntryState extends State<TvTextEntry> {
  FocusNode? _own;
  FocusNode get _node => widget.focusNode ?? (_own ??= FocusNode(debugLabel: 'champ'));
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    _own?.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_node.hasFocus && _editing) setState(() => _editing = false);
  }

  void _edit() {
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _node.requestFocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  void _done() {
    if (_editing) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.builder(context, _node, false, () {});
    return Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.arrowUp): const DirectionalFocusIntent(
          TraversalDirection.up,
          ignoreTextFields: false,
        ),
        const SingleActivator(LogicalKeyboardKey.arrowDown): const DirectionalFocusIntent(
          TraversalDirection.down,
          ignoreTextFields: false,
        ),
        if (!_editing) ...{
          const SingleActivator(LogicalKeyboardKey.arrowLeft): const DirectionalFocusIntent(
            TraversalDirection.left,
            ignoreTextFields: false,
          ),
          const SingleActivator(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(
            TraversalDirection.right,
            ignoreTextFields: false,
          ),
          const SingleActivator(LogicalKeyboardKey.select): const _TvEditIntent(),
          const SingleActivator(LogicalKeyboardKey.enter): const _TvEditIntent(),
          const SingleActivator(LogicalKeyboardKey.numpadEnter): const _TvEditIntent(),
          const SingleActivator(LogicalKeyboardKey.gameButtonA): const _TvEditIntent(),
        },
      },
      child: Actions(
        actions: {
          _TvEditIntent: CallbackAction<_TvEditIntent>(
            onInvoke: (_) {
              _edit();
              return null;
            },
          ),
        },
        child: widget.builder(context, _node, !_editing, _done),
      ),
    );
  }
}

/// Télécommande : quand le focus remonte sur un élément du haut d'une page (boutons d'une fiche,
/// carrousel de l'accueil, filtres d'une bibliothèque…), la page revient tout en haut au lieu de
/// s'arrêter juste au niveau de l'élément (titre, image de fond coupés). Valable pour toutes les
/// pages : un seul écouteur sur le focus, installé au démarrage sur téléviseur.
abstract final class TvScrollToTop {
  static FocusManager? _manager;
  static FocusNode? _last;

  static void install() {
    final manager = FocusManager.instance;
    if (identical(manager, _manager)) return;
    _manager?.removeListener(_onFocus);
    _manager = manager..addListener(_onFocus);
  }

  static void _onFocus() {
    final node = FocusManager.instance.primaryFocus;
    if (!OFDevice.tv || node == null || identical(node, _last)) return;
    _last = node;
    // Après le défilement par défaut (élément ramené à l'écran) : correction éventuelle.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(node));
  }

  static void _reveal(FocusNode node) {
    final context = node.context;
    if (context == null || !context.mounted || FocusManager.instance.primaryFocus != node) return;
    final scrollable = Scrollable.maybeOf(context, axis: Axis.vertical);
    final box = context.findRenderObject();
    final page = scrollable?.context.findRenderObject();
    if (scrollable == null || box is! RenderBox || !box.attached || page is! RenderBox || !page.attached) return;
    final position = scrollable.position;
    if (position.pixels <= position.minScrollExtent) return;
    // Bas de l'élément dans la page (et non dans une rangée horizontale) : s'il tient dans le
    // premier écran, on remonte tout en haut, titre et image de fond compris.
    final top = box.localToGlobal(Offset.zero, ancestor: page).dy + position.pixels - position.minScrollExtent;
    if (top + box.size.height <= position.viewportDimension) {
      unawaited(
        position.animateTo(
          position.minScrollExtent,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }
}
