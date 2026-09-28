import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Verre dessiné par une vue native (iOS : Liquid Glass dans la vue AVPlayer).
///
/// Les [LiquidGlass] de ce sous-arbre ne peignent que leur liseré et leur reflet ;
/// à chaque image, la portée mesure leur position, leur arrondi et leur visibilité
/// (dans le repère de [anchorKey], la vue native) et transmet la liste à [onChanged]
/// dès qu'elle change. La vue native pose alors son propre matériau dessous.
class NativeGlassScope extends StatefulWidget {
  const NativeGlassScope({super.key, required this.anchorKey, required this.onChanged, required this.child});

  /// Widget de la vue native : origine des coordonnées transmises.
  final GlobalKey anchorKey;
  final ValueChanged<List<Map<String, Object>>> onChanged;
  final Widget child;

  static NativeGlassScopeState? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_NativeGlassMarker>()?.state;

  @override
  State<NativeGlassScope> createState() => NativeGlassScopeState();
}

class NativeGlassScopeState extends State<NativeGlassScope> with SingleTickerProviderStateMixin {
  final _slots = <NativeGlassSlotState>{};
  late final Ticker _ticker = createTicker(_tick);
  String _last = '';

  void _register(NativeGlassSlotState slot) {
    _slots.add(slot);
    if (!_ticker.isActive) _ticker.start();
  }

  void _unregister(NativeGlassSlotState slot) {
    _slots.remove(slot);
    if (_slots.isEmpty) {
      _ticker.stop();
      _send(const []);
    }
  }

  void _tick(Duration _) {
    final anchor = widget.anchorKey.currentContext?.findRenderObject();
    if (anchor is! RenderBox || !anchor.attached || !anchor.hasSize) return;
    final origin = anchor.localToGlobal(Offset.zero);
    final items = <Map<String, Object>>[for (final slot in _slots) ?slot._measure(origin)];
    _send(items);
  }

  void _send(List<Map<String, Object>> items) {
    final signature = items.toString();
    if (signature == _last) return;
    _last = signature;
    widget.onChanged(items);
  }

  @override
  void dispose() {
    _ticker.dispose();
    widget.onChanged(const []);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _NativeGlassMarker(state: this, child: widget.child);
}

class _NativeGlassMarker extends InheritedWidget {
  const _NativeGlassMarker({required this.state, required super.child});

  final NativeGlassScopeState state;

  @override
  bool updateShouldNotify(_NativeGlassMarker old) => old.state != state;
}

/// Emplacement d'un verre natif (posé par [LiquidGlass] sous une [NativeGlassScope]).
class NativeGlassSlot extends StatefulWidget {
  const NativeGlassSlot({super.key, required this.scope, required this.borderRadius, required this.child});

  final NativeGlassScopeState scope;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  State<NativeGlassSlot> createState() => NativeGlassSlotState();
}

class NativeGlassSlotState extends State<NativeGlassSlot> {
  late final String _id = identityHashCode(this).toRadixString(36);
  late NativeGlassScopeState _scope = widget.scope;

  @override
  void initState() {
    super.initState();
    _scope._register(this);
  }

  @override
  void didUpdateWidget(NativeGlassSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) {
      _scope._unregister(this);
      _scope = widget.scope.._register(this);
    }
  }

  @override
  void dispose() {
    _scope._unregister(this);
    super.dispose();
  }

  static double _round(double v) => (v * 2).roundToDouble() / 2;

  /// Position (après transformations : zoom au toucher, glissements), arrondi et
  /// visibilité (produit des opacités des ancêtres) ; null si pas encore disposé.
  Map<String, Object>? _measure(Offset origin) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize || box.size.isEmpty) return null;
    final rect = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size).shift(-origin);
    final scale = rect.width / box.size.width;

    var opacity = 1.0;
    RenderObject? node = box.parent;
    while (node != null && opacity > 0) {
      if (node is RenderOpacity) {
        opacity *= node.opacity;
      } else if (node is RenderAnimatedOpacityMixin) {
        opacity *= node.opacity.value;
      } else if (node is RenderOffstage && node.offstage) {
        opacity = 0;
      }
      node = node.parent;
    }

    return {
      'id': _id,
      'x': _round(rect.left),
      'y': _round(rect.top),
      'w': _round(rect.width),
      'h': _round(rect.height),
      'r': _round(widget.borderRadius.topLeft.x.clamp(0, box.size.shortestSide / 2) * scale),
      'visible': opacity > 0.5,
    };
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
