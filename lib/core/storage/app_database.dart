import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('ServerRow')
/// Serveurs Jellyfin connus.
class Servers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get baseUrl => text()();
  TextColumn get version => text()();
  DateTimeColumn get lastUsedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AccountRow')
/// Comptes utilisateurs connectés. Le token n'est JAMAIS stocké ici
/// (voir `TokenVault`, adossé au trousseau / Keystore).
class Accounts extends Table {
  /// `<serverId>:<userId>`
  TextColumn get id => text()();
  TextColumn get serverId => text().references(Servers, #id, onDelete: KeyAction.cascade)();
  TextColumn get userId => text()();
  TextColumn get userName => text()();
  TextColumn get avatarTag => text().nullable()();
  DateTimeColumn get lastUsedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('KeyValueRow')
/// Petites préférences clé/valeur (compte actif, etc.).
class KeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Réponses API mises en cache pour un affichage instantané au démarrage à froid.
@DataClassName('CachedResponseRow')
class CachedResponses extends Table {
  /// `<accountId>/<section>`
  TextColumn get key => text()();
  TextColumn get json => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Servers, Accounts, KeyValues, CachedResponses])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'optifin'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(cachedResponses);
        },
        beforeOpen: (details) async => customStatement('PRAGMA foreign_keys = ON'),
      );
}

/// Cache clé → JSON. Les erreurs de lecture sont silencieuses : le cache n'est
/// qu'une accélération, jamais une source de vérité.
class ResponseCache {
  ResponseCache(this._db);

  final AppDatabase _db;

  Future<String?> read(String key) async {
    try {
      final row = await (_db.select(_db.cachedResponses)..where((t) => t.key.equals(key))).getSingleOrNull();
      return row?.json;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, String json) => _db
      .into(_db.cachedResponses)
      .insertOnConflictUpdate(CachedResponsesCompanion.insert(key: key, json: json, updatedAt: DateTime.now()));

  /// Purge le cache d'un compte (déconnexion).
  Future<void> clearPrefix(String prefix) =>
      (_db.delete(_db.cachedResponses)..where((t) => t.key.like('$prefix%'))).go();
}
