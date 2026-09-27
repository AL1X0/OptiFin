import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/core/logging/app_log.dart';
import 'package:optifin/features/player/domain/playback_engine.dart';
import 'package:optifin/features/player/domain/playback_plan.dart';
import 'package:optifin/features/player/domain/track_preferences.dart';
import 'package:optifin/features/settings/domain/app_settings.dart';

import '../player/fakes.dart';

void main() {
  group('AppLog', () {
    setUp(() {
      AppLog.instance.clear();
      AppLog.instance.verbose = false;
    });

    test('masque tokens, clés d’API et mots de passe', () {
      const raw = 'Authorization: MediaBrowser Client="OptiFin", Token="abc123"\n'
          'GET /videos/x/master.m3u8?MediaSourceId=1&ApiKey=deadbeef&x=1 '
          '/Items?api_key=k1 X-Emby-Token: t0ken {"AccessToken":"secret","Pw":"hunter2"}';
      final out = AppLog.redact(raw);
      for (final secret in ['abc123', 'deadbeef', 'k1 ', 't0ken', '"secret"', 'hunter2']) {
        expect(out, isNot(contains(secret)), reason: secret);
      }
      expect(out, contains('ApiKey=***'));
      expect(out, contains('MediaSourceId=1'), reason: 'le reste reste lisible');
    });

    test('niveau debug ignoré hors mode debug', () {
      AppLog.d('t', 'détail');
      AppLog.w('t', 'attention');
      expect(AppLog.instance.entries.map((e) => e.message), ['attention']);
      AppLog.instance.verbose = true;
      AppLog.d('t', 'détail');
      expect(AppLog.instance.entries, hasLength(2));
    });

    test('tampon circulaire borné et export filtrable', () {
      for (var i = 0; i < AppLog.capacity + 50; i++) {
        AppLog.i('t', 'ligne $i');
      }
      expect(AppLog.instance.entries, hasLength(AppLog.capacity));
      expect(AppLog.instance.entries.first.message, 'ligne 50');
      AppLog.e('t', 'boum', StateError('x'));
      expect(AppLog.instance.export(minLevel: LogLevel.error).split('\n').first, contains('E/t: boum'));
    });
  });

  group('AppSettings', () {
    test('aller-retour JSON', () {
      const s = AppSettings(
        debugMode: true,
        maxBitrateWifi: 40000000,
        audioLanguage: 'fre',
        subtitleMode: SubtitleMode.forcedOnly,
        subtitleScale: 1.25,
        subtitleBackground: SubtitleBackground.box,
      );
      final r = AppSettings.fromJsonString(s.toJsonString());
      expect(r.debugMode, isTrue);
      expect(r.maxBitrateWifi, 40000000);
      expect(r.audioLanguage, 'fre');
      expect(r.subtitleMode, SubtitleMode.forcedOnly);
      expect(r.subtitleStyle.scale, 1.25);
      expect(r.subtitleBackground, SubtitleBackground.box);
    });

    test('tolère JSON invalide, clés inconnues ou manquantes', () {
      expect(AppSettings.fromJsonString(null).maxBitrateCellular, 10000000);
      expect(AppSettings.fromJsonString('pas du json').debugMode, isFalse);
      final r = AppSettings.fromJsonString('{"subtitleMode":"inconnu","debugMode":"oui","futur":1}');
      expect(r.subtitleMode, SubtitleMode.server);
      expect(r.debugMode, isFalse);
    });

    test('copyWith peut remettre une langue à « choix du serveur »', () {
      const s = AppSettings(audioLanguage: 'eng');
      expect(s.copyWith(audioLanguage: () => null).audioLanguage, isNull);
    });
  });

  group('preferredTracks', () {
    PlaybackPlan p({int? audio = 1, int? sub}) => plan(audioIndex: audio, subtitleIndex: sub);

    test('codes de langue équivalents', () {
      expect(normalizeLanguage('fra'), 'fre');
      expect(normalizeLanguage('fr-FR'), 'fre');
      expect(normalizeLanguage('DEU'), 'ger');
      expect(normalizeLanguage(''), isNull);
      expect(normalizeLanguage('tlh'), 'tlh');
    });

    test('sans préférence : choix du serveur conservé', () {
      expect(preferredTracks(p(audio: 2, sub: 3), const AppSettings()), (2, 3));
    });

    test('langue audio préférée', () {
      expect(preferredTracks(p(audio: 1), const AppSettings(audioLanguage: 'eng')), (2, null));
      expect(preferredTracks(p(audio: 1), const AppSettings(audioLanguage: 'fra')).$1, 1, reason: 'déjà en français');
      expect(preferredTracks(p(audio: 1), const AppSettings(audioLanguage: 'jpn')).$1, 1, reason: 'aucune piste japonaise');
    });

    test('modes de sous-titres', () {
      expect(preferredTracks(p(sub: 3), const AppSettings(subtitleMode: SubtitleMode.none)).$2, isNull);
      expect(preferredTracks(p(), const AppSettings(subtitleMode: SubtitleMode.always)).$2, 3, reason: '1re piste non forcée');
      expect(
        preferredTracks(p(), const AppSettings(subtitleMode: SubtitleMode.forcedOnly)).$2,
        isNull,
        reason: 'aucune piste forcée',
      );
    });

    test('sous-titres forcés dans la langue choisie', () {
      const forcedFr = MediaTrack(index: 9, type: TrackType.subtitle, label: 'FR forcés', language: 'fre', isForced: true);
      final base = plan();
      final withForced = PlaybackPlan(
        itemId: base.itemId,
        mediaSourceId: base.mediaSourceId,
        playSessionId: base.playSessionId,
        method: base.method,
        streamUrl: base.streamUrl,
        audioTracks: base.audioTracks,
        subtitleTracks: [...base.subtitleTracks, forcedFr],
        audioIndex: 1,
      );
      expect(
        preferredTracks(withForced, const AppSettings(subtitleMode: SubtitleMode.forcedOnly, subtitleLanguage: 'fr')).$2,
        9,
      );
    });
  });
}
