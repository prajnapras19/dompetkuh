import 'dart:convert';

import '../db/database.dart';

/// Current backup JSON schema version. Bump this and branch in
/// [ExportImport.importFromJson] if the export shape ever changes, so old
/// backups stay restorable.
const backupSchemaVersion = 1;

/// Serializes the whole local database to/from a versioned JSON snapshot,
/// for Google Drive backup/restore. Kept as JSON (not the raw sqlite file)
/// so an older backup can still be imported after a future schema change.
class ExportImport {
  ExportImport._();

  static Future<String> exportToJson(AppDatabase db) async {
    final currencies = await db.select(db.currencies).get();
    final categories = await db.select(db.categories).get();
    final accounts = await db.select(db.accounts).get();
    final transactions = await db.select(db.transactions).get();
    final transfers = await db.select(db.transfers).get();

    final map = {
      'schemaVersion': backupSchemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'currencies': currencies.map((e) => e.toJson()).toList(),
      'categories': categories.map((e) => e.toJson()).toList(),
      'accounts': accounts.map((e) => e.toJson()).toList(),
      'transactions': transactions.map((e) => e.toJson()).toList(),
      'transfers': transfers.map((e) => e.toJson()).toList(),
    };
    return jsonEncode(map);
  }

  /// Wipes all local data and replaces it with the contents of [json].
  /// Runs in a single DB transaction, so a failure (e.g. malformed JSON)
  /// leaves existing data untouched rather than half-restored.
  static Future<void> importFromJson(AppDatabase db, String json) async {
    final map = jsonDecode(json) as Map<String, dynamic>;

    final currencies = (map['currencies'] as List)
        .map((e) => Currency.fromJson(e as Map<String, dynamic>))
        .toList();
    final categories = (map['categories'] as List)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
    final accounts = (map['accounts'] as List)
        .map((e) => Account.fromJson(e as Map<String, dynamic>))
        .toList();
    final transactions = (map['transactions'] as List)
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
    final transfers = (map['transfers'] as List)
        .map((e) => Transfer.fromJson(e as Map<String, dynamic>))
        .toList();

    await db.transaction(() async {
      // Children first, to satisfy foreign keys while clearing.
      await db.delete(db.transfers).go();
      await db.delete(db.transactions).go();
      await db.delete(db.accounts).go();
      await db.delete(db.categories).go();
      await db.delete(db.currencies).go();

      // Parents first, to satisfy foreign keys while re-inserting. Original
      // ids are preserved (toCompanion includes id), so cross-table
      // references from the backup stay intact.
      await db.batch((batch) {
        batch.insertAll(
          db.currencies,
          currencies.map((e) => e.toCompanion(true)),
        );
        batch.insertAll(
          db.categories,
          categories.map((e) => e.toCompanion(true)),
        );
        batch.insertAll(
          db.accounts,
          accounts.map((e) => e.toCompanion(true)),
        );
        batch.insertAll(
          db.transactions,
          transactions.map((e) => e.toCompanion(true)),
        );
        batch.insertAll(
          db.transfers,
          transfers.map((e) => e.toCompanion(true)),
        );
      });
    });
  }
}
