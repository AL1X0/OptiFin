import 'package:flutter/widgets.dart';

import '../core/logging/app_log.dart';

/// Titres des écrans, pour le bouton retour iOS « ‹ Accueil ».
/// Chaque écran déclare son titre ([OFRouteTitle]) ; l'observateur retient la route précédente.
abstract final class OFRouteTitles {
  static final _titles = Expando<String>('titre');
  static final _previous = Expando<Route<dynamic>>('précédente');

  /// Titre de l'écran sous la route de [context], s'il est connu.
  static String? previousOf(BuildContext context) {
    final route = ModalRoute.of(context);
    final previous = route == null ? null : _previous[route];
    return previous == null ? null : _titles[previous];
  }
}

/// Déclare le titre de la route qui contient ce widget.
class OFRouteTitle extends StatelessWidget {
  const OFRouteTitle({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route != null) OFRouteTitles._titles[route] = title;
    return child;
  }
}

/// Suit la navigation (go_router relaie aussi les piles des onglets) : route précédente de
/// chaque écran et journal de navigation (niveau debug) pour diagnostiquer les retours sur appareil.
class OFNavObserver extends NavigatorObserver {
  static String _name(Route<dynamic>? route) => route?.settings.name ?? route.runtimeType.toString();

  void _log(String message) => AppLog.d('nav', message);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) OFRouteTitles._previous[route] = previousRoute;
    _log('ouvre ${_name(route)} (${route.runtimeType})');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null && oldRoute != null) OFRouteTitles._previous[newRoute] = OFRouteTitles._previous[oldRoute];
    _log('remplace ${_name(oldRoute)} par ${_name(newRoute)}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final how = route.navigator?.userGestureInProgress ?? false ? 'glissé' : 'bouton';
    _log('retour ($how) ${_name(route)} → ${_name(previousRoute)}');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _log('retire ${_name(route)}');

  @override
  void didStartUserGesture(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _log('glissé retour commencé sur ${_name(route)}');
}
