import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optifin_native_player/optifin_native_player.dart';

import '../../../core/logging/app_log.dart';
import '../../../core/network/jellyfin_auth.dart';
import '../../../core/providers.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/engines/mpv_engine.dart';
import '../data/engines/native_engine.dart';
import '../data/engines/windows_mpv_engine.dart';
import '../data/playback_extras_repository.dart';
import '../../downloads/presentation/downloads_providers.dart';
import '../data/playback_preparer.dart';
import '../data/playback_repository.dart';
import '../domain/device_capabilities.dart';
import '../domain/engine_selector.dart';
import '../domain/playback_engine.dart';

final playbackRepositoryProvider = Provider<PlaybackRepository>((ref) {
  final session = ref.watch(sessionControllerProvider);
  if (session == null) throw StateError('Aucune session active');
  return PlaybackRepository(
    ref.watch(jellyfinClientProvider),
    userId: session.account.userId,
    baseUrl: session.server.baseUrl,
  );
});

final playbackExtrasRepositoryProvider = Provider<PlaybackExtrasRepository>((ref) {
  final session = ref.watch(sessionControllerProvider);
  if (session == null) throw StateError('Aucune session active');
  return PlaybackExtrasRepository(ref.watch(jellyfinClientProvider), userId: session.account.userId);
});

/// Capacités du lecteur natif, mesurées une fois par lancement (quelques ms)
/// par le plugin, à la première lecture ou ouverture de fiche.
final deviceCapabilitiesProvider = FutureProvider<DeviceCapabilities>((ref) async {
  Map<String, Object?>? raw;
  try {
    raw = await NativePlayers.capabilities();
  } catch (e) {
    AppLog.w('player', 'Détection des capacités impossible : $e');
  }
  final fallback = DeviceCapabilities.fallback(Platform.isWindows ? DevicePlatform.windows : DevicePlatform.other);
  final caps = raw == null ? fallback : DeviceCapabilities.fromJson(raw);
  AppLog.i('player', 'Capacités de l’appareil : ${caps.summary}');
  return caps;
});

/// Fabrique des moteurs : l'EngineSelector choisit le type, le contrôleur l'instancie.
final playbackEngineFactoryProvider = Provider<Future<PlaybackEngine> Function(EngineKind kind)>(
  (ref) =>
      (kind) async => switch (kind) {
        // Windows : libmpv native (vraie sortie HDR) ; téléphones : media_kit.
        EngineKind.mpv when Platform.isWindows => await WindowsMpvEngine.create(),
        EngineKind.mpv => await MpvEngine.create(verbose: ref.read(settingsProvider).debugMode),
        EngineKind.native => await NativeEngine.create(
          device: await ref.read(deviceCapabilitiesProvider.future),
          loadSubtitle: (url) async {
            final response = await ref
                .read(jellyfinDioProvider)
                .getUri<String>(url, options: Options(responseType: ResponseType.plain));
            return response.data ?? '';
          },
        ),
      },
);

/// Un moteur préparé d'avance : dès que la fiche (ou le carrousel) connaît le moteur
/// retenu, il est instancié pendant que l'utilisateur lit le synopsis. Au clic sur
/// Lecture, le lecteur le prend sans attendre. Un seul moteur en réserve, libéré au bout
/// de 2 minutes s'il n'a pas servi.
class EnginePool {
  EnginePool(this._factory);

  final Future<PlaybackEngine> Function(EngineKind kind) _factory;
  (EngineKind, Future<PlaybackEngine>)? _warm;
  Timer? _expiry;

  void prewarm(EngineKind kind) {
    if (_warm?.$1 == kind) return;
    _discard();
    final future = _factory(kind);
    // Échec de création : rien en réserve, le lecteur réessaiera lui-même.
    future.catchError((Object _) => _discardIf(kind)).ignore();
    _warm = (kind, future);
    _expiry = Timer(const Duration(minutes: 2), _discard);
  }

  Future<PlaybackEngine> take(EngineKind kind) {
    final warm = _warm;
    if (warm != null && warm.$1 == kind) {
      _warm = null;
      _expiry?.cancel();
      AppLog.d('player', 'Moteur pris dans la réserve');
      return warm.$2;
    }
    return _factory(kind);
  }

  PlaybackEngine _discardIf(EngineKind kind) {
    if (_warm?.$1 == kind) _warm = null;
    throw StateError('moteur indisponible');
  }

  void _discard() {
    _expiry?.cancel();
    final warm = _warm;
    _warm = null;
    if (warm != null) unawaited(warm.$2.then((e) => e.dispose(), onError: (_) {}));
  }

  void dispose() => _discard();
}

final enginePoolProvider = Provider<EnginePool>((ref) {
  final pool = EnginePool(ref.watch(playbackEngineFactoryProvider));
  ref.onDispose(pool.dispose);
  return pool;
});

/// En-têtes d'authentification transmis au moteur (jamais le token dans l'URL).
final playbackHeadersProvider = Provider<Map<String, String>>((ref) {
  final session = ref.watch(sessionControllerProvider);
  return {'Authorization': buildAuthorizationHeader(ref.watch(clientIdentityProvider), token: session?.token)};
});

/// Préparateur configuré avec les capacités, les réglages et le débit du réseau courant.
final playbackPreparerProvider = Provider<Future<PlaybackPreparer> Function()>(
  (ref) =>
      () async => PlaybackPreparer(
        repository: ref.read(playbackRepositoryProvider),
        device: await ref.read(deviceCapabilitiesProvider.future),
        settings: ref.read(settingsProvider),
        maxBitrate: await ref.read(maxBitrateResolverProvider)(),
        local: (itemId) async {
          try {
            return await ref.read(downloadsRepositoryProvider).local(itemId);
          } catch (_) {
            return null;
          }
        },
      ),
);

/// `PlaybackInfo` et choix du moteur dès l'ouverture de la fiche : quand
/// l'utilisateur appuie sur Lecture, tout est prêt et la première image arrive
/// plus vite. Conservé 2 minutes après la fermeture de la fiche.
final playbackPrefetchProvider = FutureProvider.autoDispose.family<PreparedPlayback, String>((ref, itemId) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 2), link.close);
  ref.onDispose(timer.cancel);
  final preparer = await ref.read(playbackPreparerProvider)();
  final prepared = await preparer.prepare(itemId);
  ref.read(enginePoolProvider).prewarm(prepared.decision.engine);
  return prepared;
});
