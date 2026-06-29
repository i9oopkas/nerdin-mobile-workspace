import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'daos/permission_rules_dao.dart';
import 'tables/permission_rules.dart';

part 'app_database.g.dart';

/// Nerdin's local database.
///
/// Schema version 7. Currently only contains the [PermissionRules] table
/// used by the agent permission system. OWUI tables (sync_meta, chats,
/// messages, folders, notes, etc.) have been removed.
@DriftDatabase(
  tables: [PermissionRules],
  daos: [PermissionRulesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Opens the database file for [serverId] on a background isolate.
  factory AppDatabase.forServer(String serverId) {
    return AppDatabase(
      driftDatabase(
        name: serverId,
        native: DriftNativeOptions(
          databaseDirectory: getApplicationSupportDirectory,
        ),
      ),
    );
  }

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 7) {
            // Phase 7 permission rules table.
            await m.createTable(permissionRules);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
