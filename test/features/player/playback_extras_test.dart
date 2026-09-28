import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_api/jellyfin_api.dart';
import 'package:optifin/core/media/media_item.dart';
import 'package:optifin/core/network/image_url.dart';
import 'package:optifin/features/player/data/playback_extras_repository.dart';
import 'package:optifin/features/player/domain/playback_extras.dart';

void main() {
  group('TrickplayManifest', () {
    const m = TrickplayManifest(
      width: 320,
      height: 180,
      tileWidth: 10,
      tileHeight: 10,
      thumbnailCount: 250,
      interval: Duration(seconds: 10),
    );

    test('planche et case pour une position', () {
      expect(m.tileAt(Duration.zero), const TrickplayTile(sheet: 0, column: 0, row: 0));
      expect(m.tileAt(const Duration(seconds: 125)), const TrickplayTile(sheet: 0, column: 2, row: 1));
      // 1 000 s → vignette 100 → 2e planche, première case.
      expect(m.tileAt(const Duration(seconds: 1000)), const TrickplayTile(sheet: 1, column: 0, row: 0));
    });

    test('bornée à la dernière vignette (au-delà de la fin)', () {
      expect(m.tileAt(const Duration(hours: 5)), const TrickplayTile(sheet: 2, column: 9, row: 4));
      expect(m.tileAt(const Duration(seconds: -5)), const TrickplayTile(sheet: 0, column: 0, row: 0));
    });
  });

  group('PlaybackExtras', () {
    const intro = MediaSegment(type: SegmentType.intro, start: Duration(seconds: 30), end: Duration(seconds: 90));
    const tiny = MediaSegment(type: SegmentType.recap, start: Duration(seconds: 0), end: Duration(seconds: 2));
    const outro = MediaSegment(type: SegmentType.outro, start: Duration(minutes: 40), end: Duration(minutes: 42));
    const next = MediaItem(id: 'n', name: 'Suivant', kind: MediaKind.episode);

    test('segment à passer : dedans, pas trop court, pas dans la dernière seconde', () {
      const e = PlaybackExtras(segments: [tiny, intro, outro]);
      expect(e.skippableAt(const Duration(seconds: 1)), isNull, reason: 'segment de 2 s ignoré');
      expect(e.skippableAt(const Duration(seconds: 30)), intro);
      expect(e.skippableAt(const Duration(milliseconds: 89500)), isNull);
      expect(e.skippableAt(const Duration(seconds: 90)), isNull, reason: 'fin exclue');
      expect(e.skippableAt(const Duration(minutes: 41)), outro, reason: 'pas d’épisode suivant : bouton « Passer »');
      const withNext = PlaybackExtras(segments: [outro], nextEpisode: next);
      expect(withNext.skippableAt(const Duration(minutes: 41)), isNull, reason: 'géré par la carte épisode suivant');
    });

    test('moment de l’épisode suivant : générique connu, sinon 30 s avant la fin', () {
      const total = Duration(minutes: 42);
      expect(const PlaybackExtras(segments: [outro]).upNextAt(total), isNull, reason: 'pas d’épisode suivant');
      expect(const PlaybackExtras(segments: [outro], nextEpisode: next).upNextAt(total), const Duration(minutes: 40));
      expect(const PlaybackExtras(nextEpisode: next).upNextAt(total), const Duration(minutes: 41, seconds: 30));
      // Générique « au milieu » (segment mal détecté) ignoré ; jamais avant la moitié.
      const early = MediaSegment(type: SegmentType.outro, start: Duration(minutes: 5), end: Duration(minutes: 6));
      expect(
        const PlaybackExtras(segments: [early], nextEpisode: next).upNextAt(total),
        const Duration(minutes: 41, seconds: 30),
      );
      expect(
        const PlaybackExtras(nextEpisode: next).upNextAt(const Duration(seconds: 40)),
        const Duration(seconds: 20),
      );
      expect(const PlaybackExtras(nextEpisode: next).upNextAt(Duration.zero), isNull);
    });

    test('chapitre courant', () {
      const e = PlaybackExtras(
        chapters: [
          Chapter(index: 0, start: Duration.zero, name: 'Début'),
          Chapter(index: 1, start: Duration(minutes: 10), name: 'Milieu'),
        ],
      );
      expect(e.chapterAt(const Duration(minutes: 5))?.name, 'Début');
      expect(e.chapterAt(const Duration(minutes: 10))?.name, 'Milieu');
      expect(const PlaybackExtras().chapterAt(Duration.zero), isNull);
    });
  });

  group('Mapping Jellyfin', () {
    test('chapitres : triés, nom par défaut, vignette', () {
      final dto = BaseItemDto.fromJson({
        'Id': 'm',
        'Chapters': [
          {'StartPositionTicks': 6000000000, 'Name': ' Scène 2 ', 'ImageTag': 't2'},
          {'StartPositionTicks': 0, 'Name': ''},
        ],
      });
      final chapters = PlaybackExtrasRepository.chaptersFrom(dto);
      expect(chapters.map((c) => c.name), ['Chapitre 2', 'Scène 2']);
      expect(chapters.last.start, const Duration(minutes: 10));
      expect(chapters.last.imageTag, 't2');
      expect(PlaybackExtrasRepository.chaptersFrom(null), isEmpty);
    });

    test('trickplay : bonne source, largeur la plus proche de 320 px', () {
      final dto = BaseItemDto.fromJson({
        'Id': 'm',
        'Trickplay': {
          'src': {
            '160': {
              'Width': 160,
              'Height': 90,
              'TileWidth': 10,
              'TileHeight': 10,
              'ThumbnailCount': 500,
              'Interval': 10000,
            },
            '320': {
              'Width': 320,
              'Height': 180,
              'TileWidth': 10,
              'TileHeight': 10,
              'ThumbnailCount': 500,
              'Interval': 10000,
            },
          },
        },
      });
      final m = PlaybackExtrasRepository.trickplayFrom(dto, mediaSourceId: 'src')!;
      expect((m.width, m.height, m.interval), (320, 180, const Duration(seconds: 10)));
      // Source inconnue : la première disponible.
      expect(PlaybackExtrasRepository.trickplayFrom(dto, mediaSourceId: 'autre')?.width, 320);
      expect(PlaybackExtrasRepository.trickplayFrom(BaseItemDto.fromJson({'Id': 'x'}), mediaSourceId: 'src'), isNull);
    });

    test('segments : types connus, bornes valides, triés', () {
      final segments = PlaybackExtrasRepository.segmentsFrom([
        MediaSegmentDto.fromJson({'Id': '1', 'Type': 'Outro', 'StartTicks': 24000000000, 'EndTicks': 25200000000}),
        MediaSegmentDto.fromJson({'Id': '2', 'Type': 'Intro', 'StartTicks': 300000000, 'EndTicks': 900000000}),
        MediaSegmentDto.fromJson({'Id': '3', 'Type': 'Unknown', 'StartTicks': 0, 'EndTicks': 10}),
        MediaSegmentDto.fromJson({'Id': '4', 'Type': 'Recap', 'StartTicks': 50, 'EndTicks': 10}),
      ]);
      expect(segments.map((s) => s.type), [SegmentType.intro, SegmentType.outro]);
      expect(segments.first.start, const Duration(seconds: 30));
      expect(segments.first.end, const Duration(seconds: 90));
    });

    test('sous-titres distants : correspondances exactes puis plus téléchargés', () {
      final list = PlaybackExtrasRepository.remoteSubtitlesFrom([
        RemoteSubtitleInfo.fromJson({'Id': 'a', 'Name': 'A', 'DownloadCount': 900}),
        RemoteSubtitleInfo.fromJson({'Id': 'b', 'Name': 'B', 'DownloadCount': 10, 'IsHashMatch': true}),
        RemoteSubtitleInfo.fromJson({'Name': 'sans id'}),
        RemoteSubtitleInfo.fromJson({
          'Id': 'c',
          'DownloadCount': 5000,
          'ProviderName': 'Open Subtitles',
          'Format': 'srt',
        }),
      ]);
      expect(list.map((s) => s.id), ['b', 'c', 'a']);
      expect(list[1].name, 'Sous-titre c');
      expect(list[1].detail, 'Open Subtitles · SRT · 5000 téléchargements');
      expect(list.first.detail, contains('Synchro exacte'));
    });
  });

  test('URL des planches trickplay et vignettes de chapitres', () {
    final b = JellyfinImageUrlBuilder(Uri.parse('https://h/jf'));
    expect(
      b.trickplaySheet('m', width: 320, sheet: 2, mediaSourceId: 's').toString(),
      'https://h/jf/Videos/m/Trickplay/320/2.jpg?mediaSourceId=s',
    );
    expect(b.trickplaySheet('m', width: 320, sheet: 0).toString(), 'https://h/jf/Videos/m/Trickplay/320/0.jpg');
    final chapter = b.chapterImage('m', 3, tag: 'x', logicalWidth: 128, devicePixelRatio: 2);
    expect(chapter.path, '/jf/Items/m/Images/Chapter/3');
    expect(chapter.queryParameters['maxWidth'], '320');
  });
}
