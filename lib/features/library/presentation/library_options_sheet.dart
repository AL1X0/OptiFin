import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../domain/library_query.dart';
import 'library_providers.dart';

/// Feuille « Trier et filtrer » : chaque changement s'applique immédiatement.
class LibraryOptionsSheet extends ConsumerStatefulWidget {
  const LibraryOptionsSheet({super.key, required this.initial, required this.onChanged});

  final LibraryQuery initial;
  final ValueChanged<LibraryQuery> onChanged;

  @override
  ConsumerState<LibraryOptionsSheet> createState() => _LibraryOptionsSheetState();
}

class _LibraryOptionsSheetState extends ConsumerState<LibraryOptionsSheet> {
  late LibraryQuery _q = widget.initial;

  void _update(LibraryQuery q) {
    setState(() => _q = q);
    widget.onChanged(q);
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(libraryFilterOptionsProvider(widget.initial)).value;
    final accent = Theme.of(context).colorScheme.primary;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: OFSpacing.sm, bottom: OFSpacing.sm),
          child: FilterChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => onTap(),
            showCheckmark: false,
            labelStyle: OFTypography.callout.copyWith(color: selected ? OFColors.background : OFColors.textPrimary),
            selectedColor: accent,
            backgroundColor: OFColors.surfaceRaised,
            side: BorderSide.none,
            shape: const StadiumBorder(),
          ),
        );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(OFSpacing.xl, OFSpacing.sm, OFSpacing.xl, OFSpacing.xxl),
        children: [
          Row(
            children: [
              const Expanded(child: Text('Trier et filtrer', style: OFTypography.title2)),
              if (_q.activeFilterCount > 0)
                TextButton(onPressed: () => _update(_q.clearFilters()), child: const Text('Réinitialiser')),
            ],
          ),
          const _Section('Trier par'),
          Wrap(
            children: [
              for (final s in LibrarySort.values)
                chip(s.label, _q.sort == s, () => _update(_q.copyWith(sort: s, descending: s.defaultDescending))),
            ],
          ),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Croissant'), icon: Icon(Icons.arrow_upward_rounded)),
              ButtonSegment(value: true, label: Text('Décroissant'), icon: Icon(Icons.arrow_downward_rounded)),
            ],
            selected: {_q.descending},
            onSelectionChanged: (v) => _update(_q.copyWith(descending: v.first)),
          ),
          const _Section('Statut'),
          Wrap(
            children: [
              chip('Tous', _q.played == null, () => _update(_q.copyWith(played: () => null))),
              chip('Non vus', _q.played == false, () => _update(_q.copyWith(played: () => false))),
              chip('Vus', _q.played == true, () => _update(_q.copyWith(played: () => true))),
              chip('Favoris', _q.favoritesOnly, () => _update(_q.copyWith(favoritesOnly: !_q.favoritesOnly))),
            ],
          ),
          const _Section('Résolution'),
          Wrap(
            children: [
              chip('Toutes', _q.resolution == ResolutionFilter.any, () => _update(_q.copyWith(resolution: ResolutionFilter.any))),
              chip('HD', _q.resolution == ResolutionFilter.hd, () => _update(_q.copyWith(resolution: ResolutionFilter.hd))),
              chip('4K', _q.resolution == ResolutionFilter.uhd, () => _update(_q.copyWith(resolution: ResolutionFilter.uhd))),
            ],
          ),
          if (options != null && options.genres.isNotEmpty) ...[
            const _Section('Genres'),
            Wrap(
              children: [
                for (final g in options.genres)
                  chip(g.name, _q.genreIds.contains(g.id), () {
                    final ids = [..._q.genreIds];
                    ids.contains(g.id) ? ids.remove(g.id) : ids.add(g.id);
                    _update(_q.copyWith(genreIds: ids));
                  }),
              ],
            ),
          ],
          if (options != null && options.years.isNotEmpty) ...[
            const _Section('Années'),
            Wrap(
              children: [
                for (final y in options.years)
                  chip('$y', _q.years.contains(y), () {
                    final years = [..._q.years];
                    years.contains(y) ? years.remove(y) : years.add(y);
                    _update(_q.copyWith(years: years));
                  }),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: OFSpacing.xl, bottom: OFSpacing.md),
        child: Text(
          title.toUpperCase(),
          style: OFTypography.caption.copyWith(color: OFColors.textTertiary, letterSpacing: 1.2),
        ),
      );
}
