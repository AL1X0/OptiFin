import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:optifin_native_player/optifin_native_player.dart' show NativePlayers;

import 'app/app.dart';
import 'core/design_system/design_system.dart';
import 'core/platform/device_identity.dart';
import 'core/logging/app_log.dart';
import 'core/network/retry_policy.dart';
import 'core/providers.dart';
import 'core/storage/app_database.dart';
import 'core/storage/token_vault.dart';
import 'features/settings/presentation/settings_providers.dart';

/// Démarrage minimal : uniquement ce qui est local et rapide (DB, trousseau).
/// Aucun appel réseau, aucun moteur de lecture (libmpv est chargé à la demande).
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Toute erreur non interceptée finit dans le journal (Paramètres › Journaux).
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    AppLog.e('flutter', details.exceptionAsString(), null, details.stack);
    previousOnError?.call(details);
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    AppLog.e('app', 'Erreur non interceptée', error, stack);
    return true;
  };
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  final db = AppDatabase.open();
  final vault = SecureTokenVault();
  final identityFuture = loadClientIdentity();
  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(db), tokenVaultProvider.overrideWithValue(vault)],
  );
  final session = await container.read(accountStoreProvider).restoreActiveSession();
  final settings = await loadSettings(db);
  final identity = await identityFuture;
  // Téléviseur : interface à la télécommande (voir OFDevice).
  OFDevice.tv = await NativePlayers.isTelevision();
  container.dispose();
  AppLog.instance.verbose = settings.debugMode;
  AppLog.i(
    'app',
    'Démarrage OptiFin ${identity.version}${OFDevice.tv ? ' (TV)' : ''} — session ${session == null ? 'aucune' : 'restaurée'}',
  );

  runApp(
    ProviderScope(
      retry: networkRetry,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        tokenVaultProvider.overrideWithValue(vault),
        clientIdentityProvider.overrideWithValue(identity),
        initialSessionProvider.overrideWithValue(session),
        initialSettingsProvider.overrideWithValue(settings),
      ],
      child: const OptiFinApp(),
    ),
  );
}
