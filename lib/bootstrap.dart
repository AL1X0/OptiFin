import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/platform/device_identity.dart';
import 'core/network/retry_policy.dart';
import 'core/providers.dart';
import 'core/storage/app_database.dart';
import 'core/storage/token_vault.dart';

/// Démarrage minimal : uniquement ce qui est local et rapide (DB, trousseau).
/// Aucun appel réseau, aucun moteur de lecture (libmpv est chargé à la demande).
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
  ));

  final db = AppDatabase.open();
  final vault = SecureTokenVault();
  final identityFuture = loadClientIdentity();
  final container = ProviderContainer(overrides: [
    appDatabaseProvider.overrideWithValue(db),
    tokenVaultProvider.overrideWithValue(vault),
  ]);
  final session = await container.read(accountStoreProvider).restoreActiveSession();
  final identity = await identityFuture;
  container.dispose();

  runApp(ProviderScope(
    retry: networkRetry,
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      tokenVaultProvider.overrideWithValue(vault),
      clientIdentityProvider.overrideWithValue(identity),
      initialSessionProvider.overrideWithValue(session),
    ],
    child: const OptiFinApp(),
  ));
}
