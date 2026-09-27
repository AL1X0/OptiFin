import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/core/media/media_item.dart';
import 'package:optifin/features/library/domain/library_pager.dart';
import 'package:optifin/features/library/domain/library_query.dart';

void main() {
  group('LibraryPager', () {
    late List<(int, int)> calls;
    late Map<int, Completer<PageResult<int>>> pending;

    LibraryPager<int> pager({int pageSize = 10, int maxCachedPages = 12}) {
      calls = [];
      pending = {};
      return LibraryPager<int>((start, limit) {
        calls.add((start, limit));
        return (pending[start] = Completer()).future;
      }, pageSize: pageSize, maxCachedPages: maxCachedPages);
    }

    void complete(int start, {int total = 100}) =>
        pending[start]!.complete(PageResult([for (var i = start; i < start + 10 && i < total; i++) i], total));

    test('une seule requête par page même si plusieurs cases la demandent', () async {
      final p = pager();
      expect(p.itemAt(3), isNull);
      expect(p.itemAt(7), isNull);
      expect(calls, [(0, 10)]);
      complete(0);
      await Future<void>.delayed(Duration.zero);
      expect(p.total, 100);
      expect(p.itemAt(7), 7);
      expect(calls, hasLength(1));
    });

    test('accès aléatoire : saute directement à la page 5', () async {
      final p = pager();
      expect(p.itemAt(55), isNull);
      expect(calls, [(50, 10)]);
      complete(50);
      await Future<void>.delayed(Duration.zero);
      expect(p.itemAt(55), 55);
    });

    test('notifie à chaque page chargée', () async {
      final p = pager();
      var notified = 0;
      p.addListener(() => notified++);
      unawaited(p.start());
      complete(0);
      await Future<void>.delayed(Duration.zero);
      expect(notified, 1);
    });

    test('erreur première page → error, retry relance', () async {
      final p = pager();
      unawaited(p.start());
      pending[0]!.completeError(Exception('réseau'));
      await Future<void>.delayed(Duration.zero);
      expect(p.error, isNotNull);
      expect(p.total, isNull);
      p.retry();
      expect(calls, hasLength(2));
      complete(0);
      await Future<void>.delayed(Duration.zero);
      expect(p.error, isNull);
      expect(p.itemAt(0), 0);
    });

    test('page en échec non re-demandée en boucle', () async {
      final p = pager();
      unawaited(p.start());
      complete(0);
      await Future<void>.delayed(Duration.zero);
      p.itemAt(20);
      pending[20]!.completeError(Exception('x'));
      await Future<void>.delayed(Duration.zero);
      p.itemAt(20);
      p.itemAt(21);
      expect(calls.where((c) => c.$1 == 20), hasLength(1));
      expect(p.error, isNull, reason: 'la liste reste affichée');
    });

    test('éviction LRU au-delà du plafond', () async {
      final p = pager(maxCachedPages: 2);
      for (final start in [0, 10, 20]) {
        p.itemAt(start);
        complete(start);
        await Future<void>.delayed(Duration.zero);
      }
      // La page 0 (la plus ancienne) a été évincée : nouvelle requête.
      p.itemAt(0);
      expect(calls.where((c) => c.$1 == 0), hasLength(2));
    });

    test('dispose pendant un chargement : pas d’exception', () async {
      final p = pager();
      unawaited(p.start());
      p.dispose();
      complete(0);
      await Future<void>.delayed(Duration.zero);
    });

    test('replaceWhere met à jour le cache', () async {
      final p = pager();
      unawaited(p.start());
      complete(0);
      await Future<void>.delayed(Duration.zero);
      p.replaceWhere((v) => v == 3, (v) => 300);
      expect(p.itemAt(3), 300);
    });
  });

  group('LibraryQuery', () {
    test('égalité profonde (clé de provider)', () {
      const a = LibraryQuery(parentId: 'p', kinds: [MediaKind.movie], genreIds: ['g']);
      const b = LibraryQuery(parentId: 'p', kinds: [MediaKind.movie], genreIds: ['g']);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == a.copyWith(genreIds: ['h']), isFalse);
    });

    test('copyWith played peut remettre à null', () {
      const q = LibraryQuery(played: false);
      expect(q.copyWith(played: () => null).played, isNull);
      expect(q.copyWith(sort: LibrarySort.rating).played, isFalse);
    });

    test('compteur de filtres et reset', () {
      const q = LibraryQuery(played: false, favoritesOnly: true, genreIds: ['g'], years: [2020], resolution: ResolutionFilter.uhd);
      expect(q.activeFilterCount, 5);
      expect(q.clearFilters().activeFilterCount, 0);
    });

    test('index alphabétique seulement en tri titre croissant', () {
      expect(const LibraryQuery().supportsAlphaIndex, isTrue);
      expect(const LibraryQuery(descending: true).supportsAlphaIndex, isFalse);
      expect(const LibraryQuery(sort: LibrarySort.dateAdded).supportsAlphaIndex, isFalse);
    });

    test('types et récursivité par type de bibliothèque', () {
      expect(defaultKindsFor(LibraryType.movies), [MediaKind.movie]);
      expect(defaultKindsFor(LibraryType.tvshows), [MediaKind.series]);
      expect(defaultKindsFor(LibraryType.homevideos), isEmpty);
      expect(recursiveFor(LibraryType.movies), isTrue);
      expect(recursiveFor(LibraryType.homevideos), isFalse);
      expect(recursiveFor(null), isFalse);
    });
  });
}
