import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/l10n/l.dart';
import '../../../core/media/formatters.dart';
import '../../../core/media/media_item.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../../library/domain/library_query.dart';
import '../../library/presentation/library_providers.dart';

/// Bouton « Surprends-moi » de l'accueil.
class SurpriseButton extends StatelessWidget {
  const SurpriseButton({super.key});

  void _open(BuildContext context) => showOFSheet<void>(context, builder: (_) => const SurpriseSheet());

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: L.t('Surprends-moi'),
      excludeSemantics: true,
      child: OFFocusable(
        onSelect: () => _open(context),
        scale: 1.1,
        child: GestureDetector(
          onTap: () => _open(context),
          child: GlassSurface(
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(18)),
                border: Border.all(color: OFColors.stroke),
              ),
              child: const Icon(Icons.shuffle_rounded, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}

/// Un titre tiré au sort à l'ouverture, à refaire ou à filtrer par genre et durée.
class SurpriseSheet extends ConsumerStatefulWidget {
  const SurpriseSheet({super.key});

  @override
  ConsumerState<SurpriseSheet> createState() => _SurpriseSheetState();
}

class _SurpriseSheetState extends ConsumerState<SurpriseSheet> {
  static const _query = LibraryQuery(kinds: [MediaKind.movie, MediaKind.series]);
  String? _genreId;
  int? _maxMinutes;
  MediaItem? _pick;
  String? _message;
  bool _loading = true;
  int _ticket = 0;

  @override
  void initState() {
    super.initState();
    _draw();
  }

  Future<void> _draw() async {
    final ticket = ++_ticket;
    setState(() => _loading = true);
    try {
      final pick = await ref
          .read(mediaRepositoryProvider)
          .surprise(genreId: _genreId, maxMinutes: _maxMinutes, excludeId: _pick?.id);
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _pick = pick;
        _message = pick == null ? L.t('Aucun titre ne correspond.') : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _pick = null;
        _message = e is ApiFailure ? e.userMessage : L.t('Une erreur inattendue est survenue.');
        _loading = false;
      });
    }
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: OFSpacing.sm),
    child: FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: OFTypography.callout.copyWith(color: selected ? OFColors.background : OFColors.textPrimary),
      selectedColor: Theme.of(context).colorScheme.primary,
      backgroundColor: OFColors.surfaceRaised,
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),
  );

  void _setDuration(int? minutes) {
    _maxMinutes = minutes;
    _draw();
  }

  void _setGenre(String? id) {
    _genreId = id;
    _draw();
  }

  @override
  Widget build(BuildContext context) {
    final genres = ref.watch(libraryFilterOptionsProvider(_query)).value?.genres ?? const [];
    final images = ref.watch(imageUrlBuilderProvider);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final pick = _pick;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(OFSpacing.xl, OFSpacing.sm, OFSpacing.xl, OFSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(L.t('Surprends-moi'), style: OFTypography.title2),
          const SizedBox(height: OFSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(L.t('Peu importe la durée'), _maxMinutes == null, () => _setDuration(null)),
                _chip(L.t('Moins de 1 h 30'), _maxMinutes == 90, () => _setDuration(90)),
                _chip(L.t('Moins de 2 h'), _maxMinutes == 120, () => _setDuration(120)),
              ],
            ),
          ),
          if (genres.isNotEmpty) ...[
            const SizedBox(height: OFSpacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip(L.t('Tous les genres'), _genreId == null, () => _setGenre(null)),
                  for (final g in genres) _chip(g.name, _genreId == g.id, () => _setGenre(g.id)),
                ],
              ),
            ),
          ],
          const SizedBox(height: OFSpacing.lg),
          SizedBox(
            height: 165,
            child: pick == null
                ? Center(
                    child: _loading
                        ? const CircularProgressIndicator()
                        : Text(_message ?? '', style: OFTypography.callout, textAlign: TextAlign.center),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: OFRadius.smAll,
                        child: SizedBox(
                          width: 110,
                          height: 165,
                          child: OFImage(
                            url: images.maybe(pick.poster, logicalWidth: 110, devicePixelRatio: dpr),
                            blurHash: pick.poster?.blurHash,
                            decodeWidth: (110 * dpr).ceil(),
                          ),
                        ),
                      ),
                      const SizedBox(width: OFSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pick.name, style: OFTypography.title2, maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: OFSpacing.xs),
                            Text(
                              MediaFormat.metadataLine(pick).join(' · '),
                              style: OFTypography.caption.copyWith(color: OFColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: OFSpacing.xs),
                            Expanded(
                              child: Text(
                                pick.overview ?? '',
                                style: OFTypography.caption.copyWith(color: OFColors.textSecondary),
                                overflow: TextOverflow.fade,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: OFSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OFButton(
                  label: L.t('Voir la fiche'),
                  icon: Icons.info_outline_rounded,
                  onPressed: pick == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          context.openItem(pick);
                        },
                ),
              ),
              const SizedBox(width: OFSpacing.md),
              Expanded(
                child: OFButton.secondary(
                  label: L.t('Encore'),
                  icon: Icons.shuffle_rounded,
                  onPressed: _loading ? null : _draw,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
