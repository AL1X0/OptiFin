import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_log.dart';
import '../../../core/providers.dart';
import '../../../core/storage/app_database.dart';
import '../domain/app_settings.dart';

const _settingsKey = 'settings';

/// Réglages lus au démarrage (bootstrap), pour un accès synchrone partout.
final initialSettingsProvider = Provider<AppSettings>((ref) => const AppSettings());

Future<AppSettings> loadSettings(AppDatabase db) async {
  final row = await (db.select(db.keyValues)..where((t) => t.key.equals(_settingsKey))).getSingleOrNull();
  return AppSettings.fromJsonString(row?.value);
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final initial = ref.read(initialSettingsProvider);
    AppLog.instance.verbose = initial.debugMode;
    return initial;
  }

  Future<void> update(AppSettings Function(AppSettings) change) async {
    final next = change(state);
    state = next;
    AppLog.instance.verbose = next.debugMode;
    final db = ref.read(appDatabaseProvider);
    await db
        .into(db.keyValues)
        .insertOnConflictUpdate(KeyValuesCompanion.insert(key: _settingsKey, value: next.toJsonString()));
  }
}

/// Débit max à demander au serveur selon le réseau courant (Wi-Fi / cellulaire).
/// 0 dans les réglages = pas de plafond client.
final maxBitrateResolverProvider = Provider<Future<int> Function()>((ref) {
  return () async {
    final settings = ref.read(settingsProvider);
    var cellular = false;
    try {
      final types = await Connectivity().checkConnectivity();
      cellular = types.contains(ConnectivityResult.mobile) &&
          !types.contains(ConnectivityResult.wifi) &&
          !types.contains(ConnectivityResult.ethernet);
    } catch (_) {
      // Plugin indisponible (tests) : on considère le Wi-Fi.
    }
    final chosen = cellular ? settings.maxBitrateCellular : settings.maxBitrateWifi;
    AppLog.d('player', 'Réseau ${cellular ? 'cellulaire' : 'Wi-Fi'} → débit max ${chosen == 0 ? 'illimité' : chosen}');
    return chosen == 0 ? 400000000 : chosen;
  };
});
