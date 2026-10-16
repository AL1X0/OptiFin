import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// « Remonter en haut » façon iOS : toucher la barre d'état ou l'onglet déjà actif.
/// Seul l'écran visible répond (onglet actif, route au sommet de sa pile).
abstract final class OFScrollToTop {
  static final _requests = ValueNotifier(0);

  static void request() => _requests.value++;
}

/// Remonte [controller] (à défaut, le PrimaryScrollController de la route) à chaque demande.
class ScrollToTopListener extends StatefulWidget {
  const ScrollToTopListener({super.key, this.controller, required this.child});

  final ScrollController? controller;
  final Widget child;

  @override
  State<ScrollToTopListener> createState() => _ScrollToTopListenerState();
}

class _ScrollToTopListenerState extends State<ScrollToTopListener> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    OFScrollToTop._requests.addListener(_scrollToTop);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    OFScrollToTop._requests.removeListener(_scrollToTop);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Toucher de la barre d'état iOS, diffusé à tous les observateurs.
  @override
  void handleStatusBarTap() => _scrollToTop();

  void _scrollToTop() {
    if (!mounted) return;
    // Onglets inactifs : TickerMode coupé par FadingBranches. Pages recouvertes : route non courante.
    if (!TickerMode.getValuesNotifier(context).value.enabled || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final controller = widget.controller ?? PrimaryScrollController.maybeOf(context);
    if (controller == null || !controller.hasClients || controller.offset <= 0) return;
    final motion = OFMotion.of(context);
    if (!motion.enabled) {
      controller.jumpTo(0);
      return;
    }
    controller.animateTo(0, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
