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

@DriftDatabase(tables: [Servers, Accounts, KeyValues])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'optifin'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async => customStatement('PRAGMA foreign_keys = ON'),
      );
}
