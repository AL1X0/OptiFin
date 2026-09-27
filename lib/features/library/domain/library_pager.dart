import 'dart:async';

import 'package:flutter/foundation.dart';

/// Page de résultats : éléments + total côté serveur.
class PageResult<T> {
  const PageResult(this.items, this.total);

  final List<T> items;
  final int total;
}

typedef PageFetcher<T> = Future<PageResult<T>> Function(int startIndex, int limit);

/// Accès aléatoire paginé à une liste serveur potentiellement énorme.
///
/// La grille demande `itemAt(i)` pour chaque case visible ; si la page n'est pas
/// en cache elle est chargée (une seule requête par page, même si 50 cases la
/// demandent). Permet de sauter directement à la lettre « M » d'une bibliothèque
/// de 20 000 films sans charger ce qui précède.
class LibraryPager<T> extends ChangeNotifier {
  LibraryPager(this._fetch, {this.pageSize = 100, this.maxCachedPages = 12});

  final PageFetcher<T> _fetch;
  final int pageSize;

  /// Borne mémoire : les pages les moins récemment utilisées sont évincées.
  final int maxCachedPages;

  final _pages = <int, List<T>>{};
  final _inFlight = <int>{};
  final _failed = <int>{};
  int? _total;
  Object? _error;
  bool _disposed = false;

  /// null tant que la première page n'est pas arrivée.
  int? get total => _total;

  /// Erreur de la première page (écran vide) ; les erreurs de pages suivantes
  /// laissent des cases vides réessayables via [retry].
  Object? get error => _total == null ? _error : null;

  bool get isEmpty => _total == 0;

  /// Charge la première page.
  Future<void> start() => _load(0);

  T? itemAt(int index) {
    final page = index ~/ pageSize;
    final items = _pages[page];
    if (items == null) {
      if (!_failed.contains(page)) unawaited(_load(page));
      return null;
    }
    // Rafraîchit la page en LRU.
    _pages.remove(page);
    _pages[page] = items;
    final offset = index % pageSize;
    return offset < items.length ? items[offset] : null;
  }

  /// Précharge la page contenant [index] (ex. après un saut alphabétique).
  Future<void> ensureLoaded(int index) => _load(index ~/ pageSize);

  void retry() {
    _failed.clear();
    _error = null;
    if (_total == null) {
      unawaited(_load(0));
    } else {
      _notify();
    }
  }

  /// Remplace un élément en cache (ex. favori basculé depuis la fiche).
  void replaceWhere(bool Function(T) test, T Function(T) update) {
    var changed = false;
    for (final page in _pages.values) {
      for (var i = 0; i < page.length; i++) {
        if (test(page[i])) {
          page[i] = update(page[i]);
          changed = true;
        }
      }
    }
    if (changed) _notify();
  }

  Future<void> _load(int page) async {
    if (_pages.containsKey(page) || _inFlight.contains(page)) return;
    _inFlight.add(page);
    try {
      final result = await _fetch(page * pageSize, pageSize);
      if (_disposed) return;
      _pages[page] = List.of(result.items);
      _total = result.total;
      _failed.remove(page);
      _evict();
    } catch (e) {
      if (_disposed) return;
      _failed.add(page);
      _error = e;
    } finally {
      _inFlight.remove(page);
    }
    _notify();
  }

  void _evict() {
    while (_pages.length > maxCachedPages) {
      _pages.remove(_pages.keys.first);
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
