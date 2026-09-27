import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_api/jellyfin_api.dart' hide PersonKind, VideoRange;
import 'package:optifin/core/media/formatters.dart';
import 'package:optifin/core/media/media_item.dart';
import 'package:optifin/core/media/media_mapper.dart';
import 'package:optifin/core/media/quality_badges.dart';

import '../../helpers/fixtures.dart';

MediaItem map(Map<String, Object?> json) => MediaMapper.fromDto(BaseItemDto.fromJson(json));

void main() {
  group('MediaMapper', () {
    test('film complet : images, blurhash, métadonnées, userData', () {
      final item = map(dtoJson(id: 'm1', name: 'Dune', extra: {
        'ProductionYear': 2021,
        'RunTimeTicks': 93000000000, // 2 h 35 min
        'CommunityRating': 8.1,
        'OfficialRating': '12',
        'Overview': 'Paul <i>Atréides</i>&amp;co<br/>suite',
        'Taglines': ['Au-delà de la peur'],
        'ImageTags': {'Primary': 'p1', 'Logo': 'l1', 'Thumb': 't1'},
        'BackdropImageTags': ['b1', 'b2'],
        'ImageBlurHashes': {
          'Primary': {'p1': 'LEHV6nWB2yk8'},
          'Backdrop': {'b1': 'L6PZfSi_.AyE'},
        },
        'UserData': {'Key': 'k', 'PlaybackPositionTicks': 36000000000, 'PlayedPercentage': 38.7, 'IsFavorite': true, 'Played': false},
        'GenreItems': [
          {'Name': 'Science-fiction', 'Id': 'g1'},
        ],
        'People': [
          {'Name': 'Denis Villeneuve', 'Id': 'p1', 'Type': 'Director'},
          {'Name': 'Timothée Chalamet', 'Id': 'p2', 'Type': 'Actor', 'Role': 'Paul', 'PrimaryImageTag': 'pi'},
        ],
        'RemoteTrailers': [
          {'Url': 'https://youtu.be/x', 'Name': 'Trailer'},
          {'Url': 'pas une url'},
        ],
      }));

      expect(item.kind, MediaKind.movie);
      expect(item.overview, 'Paul Atréides&co\nsuite');
      expect(item.tagline, 'Au-delà de la peur');
      expect(item.primary, const ImageRef(itemId: 'm1', type: ImageKind.primary, tag: 'p1'));
      expect(item.primary!.blurHash, 'LEHV6nWB2yk8');
      expect(item.backdrops.map((b) => b.index), [0, 1]);
      expect(item.backdrop!.blurHash, 'L6PZfSi_.AyE');
      expect(item.logo!.tag, 'l1');
      expect(item.landscape!.type, ImageKind.thumb, reason: 'thumb prioritaire pour un film en paysage');
      expect(item.user.favorite, isTrue);
      expect(item.user.progress, closeTo(0.387, 1e-6));
      expect(item.resumePosition, const Duration(hours: 1));
      expect(item.genres.single.name, 'Science-fiction');
      expect(item.people.last.role, 'Paul');
      expect(item.people.last.image!.tag, 'pi');
      expect(item.people.first.kind, PersonKind.director);
      expect(item.trailers, hasLength(1));
      expect(MediaFormat.metadataLine(item), ['2021', '2 h 35 min', '12', '★ 8,1']);
    });

    test('épisode : images héritées de la série', () {
      final ep = map(dtoJson(id: 'e1', type: 'Episode', name: 'Pilote', extra: {
        'SeriesId': 's1',
        'SeriesName': 'Severance',
        'IndexNumber': 1,
        'ParentIndexNumber': 2,
        'ImageTags': {'Primary': 'shot'},
        'SeriesPrimaryImageTag': 'sp',
        'ParentBackdropItemId': 's1',
        'ParentBackdropImageTags': ['sb'],
        'ParentLogoItemId': 's1',
        'ParentLogoImageTag': 'sl',
        'ParentThumbItemId': 's1',
        'ParentThumbImageTag': 'st',
      }));
      expect(ep.episodeLabel, 'S2 · É1');
      expect(ep.poster, const ImageRef(itemId: 's1', type: ImageKind.primary, tag: 'sp'));
      expect(ep.landscape, const ImageRef(itemId: 'e1', type: ImageKind.primary, tag: 'shot'));
      expect(ep.backdrop, const ImageRef(itemId: 's1', type: ImageKind.backdrop, tag: 'sb'));
      expect(ep.logo, const ImageRef(itemId: 's1', type: ImageKind.logo, tag: 'sl'));
    });

    test('épisode spécial', () {
      final ep = map(dtoJson(id: 'e', type: 'Episode', extra: {'ParentIndexNumber': 0, 'IndexNumber': 3}));
      expect(ep.episodeLabel, 'Spécial 3');
    });

    test('élément sans image ni données : valeurs sûres', () {
      final item = map(dtoJson(id: 'x', type: 'Folder', name: null)..remove('Name'));
      expect(item.name, '');
      expect(item.kind, MediaKind.folder);
      expect(item.primary, isNull);
      expect(item.backdrop, isNull);
      expect(item.landscape, isNull);
      expect(item.user.progress, isNull);
      expect(item.overview, isNull);
    });

    test('compatibilité : champs récents absents (serveur plus ancien) tolérés', () {
      // Réponse minimale type 10.9 : pas de HasSegments, SupportsProbing, etc.
      final item = map(dtoJson(id: 'm', extra: {
        'MediaSources': [
          {'Id': 'src', 'MediaStreams': [videoStream()]},
        ],
        'UserData': <String, Object?>{},
      }));
      expect(item.streams.single.isVideo, isTrue);
    });

    test('type absent → other', () {
      expect(map({'Id': 'x'}).kind, MediaKind.other);
    });

    test('type inconnu du client → other', () {
      expect(map(dtoJson(id: 'x', type: 'Book')).kind, MediaKind.other);
    });

    test('flux : Dolby Vision + TrueHD Atmos → badges', () {
      final item = map(dtoJson(id: 'm', extra: {
        'MediaSources': [
          {
            'Protocol': 'File',
            'Type': 'Default',
            'IsRemote': false,
            'ReadAtNativeFramerate': false,
            'IgnoreDts': false,
            'IgnoreIndex': false,
            'GenPtsInput': false,
            'SupportsTranscoding': true,
            'SupportsDirectStream': true,
            'SupportsDirectPlay': true,
            'IsInfiniteStream': false,
            'UseMostCompatibleTranscodingProfile': false,
            'RequiresOpening': false,
            'RequiresClosing': false,
            'RequiresLooping': false,
            'SupportsProbing': true,
            'MediaStreams': [videoStream(rangeType: 'DOVIWithHDR10'), audioStream()],
          },
        ],
      }));
      expect(qualityBadges(item.streams), ['4K', 'Dolby Vision', 'Atmos', '7.1']);
    });
  });

  group('qualityBadges', () {
    const v1080 = StreamSummary.video(codec: 'h264', width: 1920, height: 800);
    test('scope 2.39:1 reste 1080p', () => expect(qualityBadges(const [v1080]), ['1080p']));

    test('meilleur audio gagne, un seul badge audio', () {
      expect(
        qualityBadges(const [
          v1080,
          StreamSummary.audio(codec: 'ac3', channels: 6),
          StreamSummary.audio(codec: 'dts', profile: 'DTS-HD MA', channels: 8),
        ]),
        ['1080p', 'DTS-HD MA', '7.1'],
      );
    });

    test('DTS:X, E-AC3, stéréo sans badge canaux', () {
      expect(qualityBadges(const [StreamSummary.audio(codec: 'dts', spatial: SpatialAudio.dtsX, channels: 8)]), ['DTS:X', '7.1']);
      expect(qualityBadges(const [StreamSummary.audio(codec: 'eac3', channels: 2)]), ['Dolby Digital+']);
      expect(qualityBadges(const [StreamSummary.audio(codec: 'aac', channels: 2)]), isEmpty);
    });

    test('résolutions', () {
      expect(resolutionLabel(3840, 2160), '4K');
      expect(resolutionLabel(4096, 1716), '4K');
      expect(resolutionLabel(1280, 720), '720p');
      expect(resolutionLabel(720, 576), 'SD');
      expect(resolutionLabel(null, 100), isNull);
    });

    test('HDR10+ / HLG / SDR', () {
      expect(qualityBadges(const [StreamSummary.video(codec: 'hevc', width: 3840, height: 2160, videoRange: VideoRange.hdr10Plus)]),
          ['4K', 'HDR10+']);
      expect(qualityBadges(const [StreamSummary.video(codec: 'hevc', width: 1920, height: 1080, videoRange: VideoRange.hlg)]),
          ['1080p', 'HLG']);
    });
  });

  group('MediaFormat', () {
    test('durées', () {
      expect(MediaFormat.duration(const Duration(minutes: 48)), '48 min');
      expect(MediaFormat.duration(const Duration(hours: 2)), '2 h');
      expect(MediaFormat.duration(const Duration(hours: 2, minutes: 5)), '2 h 05 min');
      expect(MediaFormat.duration(Duration.zero), isNull);
      expect(MediaFormat.clock(const Duration(minutes: 3, seconds: 7)), '3:07');
      expect(MediaFormat.clock(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    });

    test('années de série', () {
      MediaItem series(String status, int? end) => MediaItem(
            id: 's',
            name: 'S',
            kind: MediaKind.series,
            year: 2016,
            status: status,
            endDate: end == null ? null : DateTime(end),
          );
      expect(MediaFormat.years(series('Continuing', null)), '2016 –');
      expect(MediaFormat.years(series('Ended', 2022)), '2016 – 2022');
      expect(MediaFormat.years(series('Ended', 2016)), '2016');
    });

    test('temps restant', () {
      const item = MediaItem(
        id: 'm',
        name: 'M',
        kind: MediaKind.movie,
        runTimeTicks: 72000000000, // 2 h
        user: UserState(positionTicks: 36000000000), // 1 h
      );
      expect(MediaFormat.remaining(item), '1 h restantes');
    });
  });
}
