import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optifin_native_player/optifin_native_player.dart';

import '../../../core/logging/app_log.dart';
import '../../../core/network/jellyfin_auth.dart';
import '../../../core/providers.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/engines/mpv_engine.dart';
import '../data/engines/native_engine.dart';
import '../data/playback_extras_repository.dart';
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
  final caps = raw == null ? DeviceCapabilities.fallback(DevicePlatform.other) : DeviceCapabilities.fromJson(raw);
  AppLog.i('player', 'Capacités de l’appareil : ${caps.summary}');
  return caps;
});

/// Fabrique des moteurs : l'EngineSelector choisit le type, le contrôleur l'instancie.
final playbackEngineFactoryProvider = Provider<Future<PlaybackEngine> Function(EngineKind kind)>(
  (ref) =>
      (kind) async => switch (kind) {
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
  return preparer.prepare(itemId);
});
