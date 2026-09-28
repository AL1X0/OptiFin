import 'package:jellyfin_api/jellyfin_api.dart' hide PlayMethod;

import '../../../core/network/api_failure.dart';
import '../domain/playback_plan.dart';
import '../domain/playback_reporter.dart';
import 'device_profiles.dart';
import 'source_profile_mapper.dart';

/// Lecture refusée par le serveur (droits, aucun flux compatible, limite de débit).
class PlaybackDeniedFailure extends ApiFailure {
  const PlaybackDeniedFailure(this.reason);

  final String reason;

  @override
  String get userMessage => switch (reason) {
    'NotAllowed' => 'La lecture de ce contenu n’est pas autorisée pour votre compte.',
    'NoCompatibleStream' => 'Aucun flux compatible : le serveur ne peut pas préparer ce fichier.',
    'RateLimitExceeded' => 'Limite de débit du serveur atteinte. Réessayez plus tard.',
    _ => 'Le serveur a refusé la lecture ($reason).',
  };
}

/// Préparation des lectures (PlaybackInfo) et reporting de progression.
class PlaybackRepository implements PlaybackReportSink {
  PlaybackRepository(this._api, {required this.userId, required this.baseUrl});

  final JellyfinClient _api;
  final String userId;
  final Uri baseUrl;

  /// Demande au serveur comment lire [itemId] avec les [options] d'une décision
  /// de l'EngineSelector (profil mpv par défaut : accepte tout en lecture directe).
  Future<PlaybackPlan> prepare({
    required String itemId,
    Duration start = Duration.zero,
    int? audioIndex,
    int? subtitleIndex,
    String? mediaSourceId,
    PlaybackRequestOptions? options,
    int maxStreamingBitrate = defaultMaxStreamingBitrate,
  }) async {
    final o = options ?? PlaybackRequestOptions.mpv(maxStreamingBitrate);
    final PlaybackInfoResponse response;
    try {
      response = await _api.mediaInfo.getPostedPlaybackInfo(
        itemId: itemId,
        body: PlaybackInfoDto.fromJson({
          'UserId': userId,
          'MaxStreamingBitrate': maxStreamingBitrate,
          'StartTimeTicks': start.inMicroseconds * 10,
          'AudioStreamIndex': ?audioIndex,
          'SubtitleStreamIndex': ?subtitleIndex,
          'MediaSourceId': ?mediaSourceId,
          'DeviceProfile': o.deviceProfile,
          'EnableDirectPlay': o.enableDirectPlay,
          'EnableDirectStream': o.enableDirectStream,
          'EnableTranscoding': true,
          'AllowVideoStreamCopy': o.allowVideoStreamCopy,
          'AllowAudioStreamCopy': true,
          'AutoOpenLiveStream': true,
        }),
      );
    } catch (e) {
      throw ApiFailure.from(e);
    }
    return planFromResponse(
      response,
      itemId: itemId,
      baseUrl: baseUrl,
      start: start,
      requestedAudio: audioIndex,
      requestedSubtitle: subtitleIndex,
    );
  }

  /// Réponse `PlaybackInfo` brute pour un téléchargement : profil mpv (tout en lecture
  /// directe), débit illimité — le fichier d'origine, conservé tel quel.
  Future<PlaybackInfoResponse> downloadInfo(String itemId) async {
    const unlimited = 400000000;
    final o = PlaybackRequestOptions.mpv(unlimited);
    try {
      return await _api.mediaInfo.getPostedPlaybackInfo(
        itemId: itemId,
        body: PlaybackInfoDto.fromJson({
          'UserId': userId,
          'MaxStreamingBitrate': unlimited,
          'DeviceProfile': o.deviceProfile,
          'EnableDirectPlay': true,
          'EnableDirectStream': false,
          'EnableTranscoding': false,
        }),
      );
    } catch (e) {
      throw ApiFailure.from(e);
    }
  }

  /// Convertit la réponse `PlaybackInfo` en plan de lecture. Pur, testé.
  static PlaybackPlan planFromResponse(
    PlaybackInfoResponse response, {
    required String itemId,
    required Uri baseUrl,
    Duration start = Duration.zero,
    int? requestedAudio,
    int? requestedSubtitle,
  }) {
    final code = response.errorCode;
    if (code != null && code != PlaybackInfoResponseErrorCode.$unknown) {
      throw PlaybackDeniedFailure(code.toString());
    }
    final source = response.mediaSources?.firstOrNull;
    if (source == null) throw const PlaybackDeniedFailure('NoCompatibleStream');

    final PlayMethod method;
    final Uri url;
    if (source.supportsDirectPlay ?? false) {
      method = PlayMethod.directPlay;
      url = resolve(baseUrl, 'Videos/$itemId/stream', {
        'static': 'true',
        'mediaSourceId': source.id ?? itemId,
        'playSessionId': ?response.playSessionId,
        'tag': ?source.eTag,
      });
    } else if (source.transcodingUrl != null) {
      method = (source.supportsDirectStream ?? false) ? PlayMethod.directStream : PlayMethod.transcode;
      url = resolve(baseUrl, source.transcodingUrl!);
    } else {
      throw const PlaybackDeniedFailure('NoCompatibleStream');
    }

    final streams = [...?source.mediaStreams]..sort((a, b) => (a.index ?? 0).compareTo(b.index ?? 0));
    final audio = [
      for (final s in streams)
        if (s.type == MediaStreamType.audio && s.index != null) _track(s, TrackType.audio),
    ];
    final subtitles = [
      for (final s in streams)
        if (s.type == MediaStreamType.subtitle && s.index != null) _track(s, TrackType.subtitle),
    ];

    final defaultSub = requestedSubtitle ?? source.defaultSubtitleStreamIndex;
    return PlaybackPlan(
      itemId: itemId,
      mediaSourceId: source.id ?? itemId,
      playSessionId: response.playSessionId,
      method: method,
      streamUrl: url,
      audioTracks: audio,
      subtitleTracks: subtitles,
      audioIndex: requestedAudio ?? source.defaultAudioStreamIndex ?? audio.firstOrNull?.index,
      // -1 = « aucun » côté Jellyfin.
      subtitleIndex: defaultSub == null || defaultSub < 0 || !subtitles.any((t) => t.index == defaultSub)
          ? null
          : defaultSub,
      container: source.container,
      bitrate: source.bitrate,
      videoCodec: streams.where((s) => s.type == MediaStreamType.video).firstOrNull?.codec,
      startPosition: start,
      runtime: source.runTimeTicks == null ? null : Duration(microseconds: source.runTimeTicks! ~/ 10),
      source: sourceProfileFrom(source),
    );
  }

  /// Même source lue telle quelle (flux statique) : ce que mpv lit sans aide du serveur.
  PlaybackPlan asDirectPlay(PlaybackPlan p) {
    if (p.method == PlayMethod.directPlay) return p;
    return PlaybackPlan(
      itemId: p.itemId,
      mediaSourceId: p.mediaSourceId,
      playSessionId: p.playSessionId,
      method: PlayMethod.directPlay,
      streamUrl: resolve(baseUrl, 'Videos/${p.itemId}/stream', {
        'static': 'true',
        'mediaSourceId': p.mediaSourceId,
        'playSessionId': ?p.playSessionId,
      }),
      audioTracks: p.audioTracks,
      subtitleTracks: p.subtitleTracks,
      audioIndex: p.audioIndex,
      subtitleIndex: p.subtitleIndex,
      container: p.container,
      bitrate: p.bitrate,
      videoCodec: p.videoCodec,
      startPosition: p.startPosition,
      runtime: p.runtime,
      source: p.source,
    );
  }

  static MediaTrack _track(MediaStream s, TrackType type) {
    final language = s.language;
    final codec = s.codec?.toLowerCase();
    final fallback = [
      if (language != null && language.isNotEmpty) language.toUpperCase(),
      if (codec != null) codec.toUpperCase(),
      if (type == TrackType.audio && s.channels != null) '${s.channels} can.',
    ].join(' · ');
    return MediaTrack(
      index: s.index!,
      type: type,
      label: (s.displayTitle?.isNotEmpty ?? false)
          ? s.displayTitle!
          : (fallback.isEmpty ? 'Piste ${s.index}' : fallback),
      language: language,
      codec: codec,
      isDefault: s.isDefault ?? false,
      isForced: s.isForced ?? false,
      isExternal: s.isExternal ?? false,
      isTextBased: s.isTextSubtitleStream ?? true,
      deliveryUrl: s.deliveryUrl,
      channels: s.channels,
    );
  }

  /// Résout un chemin serveur (éventuellement avec query) contre l'URL de base,
  /// en conservant un sous-chemin de reverse proxy (`https://h/jellyfin`).
  static Uri resolve(Uri base, String path, [Map<String, String>? query]) {
    final basePath = base.path.endsWith('/') ? base.path : '${base.path}/';
    final relative = Uri.parse(path.startsWith('/') ? path.substring(1) : path);
    final merged = {...relative.queryParameters, ...?query};
    return base.replace(path: '$basePath${relative.path}', queryParameters: merged.isEmpty ? null : merged);
  }

  // ------------------------------------------------------------ Reporting

  Map<String, Object?> _reportJson(PlaybackReport r) => {
    'ItemId': r.itemId,
    'MediaSourceId': r.mediaSourceId,
    'PlaySessionId': ?r.playSessionId,
    'PositionTicks': r.positionTicks,
    'IsPaused': r.isPaused,
    'IsMuted': false,
    'CanSeek': true,
    'PlayMethod': r.method.apiName,
    'AudioStreamIndex': ?r.audioIndex,
    'SubtitleStreamIndex': r.subtitleIndex ?? -1,
  };

  @override
  Future<void> start(PlaybackReport report) =>
      _api.session.reportPlaybackStart(body: PlaybackStartInfo.fromJson(_reportJson(report)));

  @override
  Future<void> progress(PlaybackReport report) =>
      _api.session.reportPlaybackProgress(body: PlaybackProgressInfo.fromJson(_reportJson(report)));

  @override
  Future<void> stopped(PlaybackReport report) => _api.session.reportPlaybackStopped(
    body: PlaybackStopInfo.fromJson({
      'ItemId': report.itemId,
      'MediaSourceId': report.mediaSourceId,
      'PlaySessionId': ?report.playSessionId,
      'PositionTicks': report.positionTicks,
      'Failed': report.failed,
    }),
  );
}
