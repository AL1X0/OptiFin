import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/media/media_item.dart';
import '../../../core/media/media_repository.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../../common/presentation/media_cards.dart';
import '../../home/domain/home_data.dart';

/// Terme de recherche courant (déjà « debouncé »).
final searchTermProvider = NotifierProvider<SearchTerm, String>(SearchTerm.new);

class SearchTerm extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final searchResultsProvider = FutureProvider.autoDispose<SearchResults?>((ref) async {
  final term = ref.watch(searchTermProvider).trim();
  if (term.length < 2) return null;
  return ref.watch(mediaRepositoryProvider).search(term);
});

/// Recherche globale instantanée : films, séries, épisodes, personnes, musique.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final _controller = TextEditingController(text: ref.read(searchTermProvider));
  final _focus = FocusNode();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // 300 ms : assez court pour paraître instantané, assez long pour ne pas
    // envoyer une requête par frappe.
    _debounce = Timer(const Duration(milliseconds: 300), () => ref.read(searchTermProvider.notifier).set(value));
    setState(() {}); // bouton « effacer »
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final gutter = OFSpacing.gutterOf(context);
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, OFSpacing.lg, gutter, OFSpacing.md),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                style: OFTypography.body,
                cursorColor: accent,
                decoration: InputDecoration(
                  hintText: 'Films, séries, personnes, musique…',
                  hintStyle: OFTypography.body.copyWith(color: OFColors.textTertiary),
                  prefixIcon: const Icon(Icons.search_rounded, color: OFColors.textSecondary),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer',
                          icon: const Icon(Icons.close_rounded, color: OFColors.textSecondary),
                          onPressed: () {
                            _controller.clear();
                            _onChanged('');
                            _focus.requestFocus();
                          },
                        ),
                  filled: true,
                  fillColor: OFColors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: OFSpacing.md),
                  border: const OutlineInputBorder(borderRadius: OFRadius.mdAll, borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: FadeThroughSwitcher(
                child: switch (results) {
                  AsyncData(value: null) => const StatusMessage(
                    key: ValueKey('accueil'),
                    icon: Icons.search_rounded,
                    text: 'Recherchez dans toutes vos bibliothèques.',
                  ),
                  AsyncData(:final value?) when value.isEmpty => StatusMessage(
                    key: const ValueKey('aucun'),
                    icon: Icons.search_off_rounded,
                    text: 'Aucun résultat pour « ${ref.read(searchTermProvider)} ».',
                  ),
                  // Nouvelle recherche : nouvelles entrées animées.
                  AsyncData(:final value?) => _Results(key: ValueKey(value), results: value),
                  AsyncError(:final error) => StatusMessage(
                    key: const ValueKey('erreur'),
                    text: error is ApiFailure ? error.userMessage : 'La recherche a échoué.',
                    onRetry: () => ref.invalidate(searchResultsProvider),
                  ),
                  _ => const Center(key: ValueKey('chargement'), child: OFLoader()),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({super.key, required this.results});

  final SearchResults results;

  @override
  Widget build(BuildContext context) {
    final sections = <(String, List<MediaItem>, CardStyle)>[
      ('Films', results.movies, CardStyle.poster),
      ('Séries', results.series, CardStyle.poster),
      ('Épisodes', results.episodes, CardStyle.landscape),
      ('Collections et vidéos', results.others, CardStyle.poster),
      ('Artistes', results.artists, CardStyle.square),
      ('Albums', results.albums, CardStyle.square),
      ('Morceaux', results.songs, CardStyle.square),
    ].where((s) => s.$2.isNotEmpty).toList();

    return EntranceScope(
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(top: OFSpacing.md, bottom: MediaQuery.paddingOf(context).bottom + 96),
        children: [
          for (final (i, s) in sections.indexed) ...[
            if (i > 0) const SizedBox(height: OFSpacing.xxl),
            FadeSlideIn(
              delay: staggerDelay(i),
              child: MediaItemsRow(title: s.$1, items: s.$2, style: s.$3, heroScope: 'search-$i'),
            ),
          ],
          if (results.people.isNotEmpty) ...[
            if (sections.isNotEmpty) const SizedBox(height: OFSpacing.xxl),
            FadeSlideIn(
              delay: staggerDelay(sections.length),
              child: _PeopleRow(people: results.people),
            ),
          ],
        ],
      ),
    );
  }
}

class _PeopleRow extends ConsumerWidget {
  const _PeopleRow({required this.people});

  final List<MediaItem> people;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(imageUrlBuilderProvider);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    const size = 84.0;
    return MediaRow(
      title: 'Personnes',
      itemCount: people.length,
      itemExtent: size + OFSpacing.lg,
      height: size + 32,
      itemBuilder: (context, i) {
        final p = people[i];
        return Semantics(
          button: true,
          label: p.name,
          excludeSemantics: true,
          onTap: () => context.openPerson(p.id),
          child: OFFocusable(
            onSelect: () => context.openPerson(p.id),
            borderRadius: const BorderRadius.all(Radius.circular(OFRadius.md)),
            child: GestureDetector(
              onTap: () => context.openPerson(p.id),
              child: Column(
                children: [
                  AvatarChip(
                    name: p.name,
                    size: size,
                    imageUrl: images.maybe(p.primary, logicalWidth: size, devicePixelRatio: dpr),
                  ),
                  const SizedBox(height: OFSpacing.sm),
                  SizedBox(
                    width: size,
                    child: Text(
                      p.name,
                      textAlign: TextAlign.center,
                      style: OFTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
