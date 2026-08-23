import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../models/ledger_entry.dart';
import 'database_provider.dart';

const _ledgerSql = '''
  SELECT 'transaction' AS kind, t.id AS id, t.date AS date, t.type AS sign_type,
    t.amount AS amount, c.icon AS icon, c.color AS color, c.name AS title,
    t.note AS note
  FROM transactions t
  INNER JOIN categories c ON c.id = t.category_id
  WHERE t.account_id = ?

  UNION ALL

  SELECT 'transfer_out' AS kind, tr.id AS id, tr.date AS date, 'out' AS sign_type,
    tr.from_amount AS amount, 'transfer' AS icon, NULL AS color,
    'Transfer to ' || dest.name AS title, tr.note AS note
  FROM transfers tr
  INNER JOIN accounts dest ON dest.id = tr.to_account_id
  WHERE tr.from_account_id = ?

  UNION ALL

  SELECT 'transfer_in' AS kind, tr.id AS id, tr.date AS date, 'in' AS sign_type,
    tr.to_amount AS amount, 'transfer' AS icon, NULL AS color,
    'Transfer from ' || src.name AS title, tr.note AS note
  FROM transfers tr
  INNER JOIN accounts src ON src.id = tr.from_account_id
  WHERE tr.to_account_id = ?

  ORDER BY date DESC
''';

LedgerKind _parseKind(String raw) => switch (raw) {
  'transaction' => LedgerKind.transaction,
  'transfer_out' => LedgerKind.transferOut,
  'transfer_in' => LedgerKind.transferIn,
  _ => throw ArgumentError('Unknown ledger kind: $raw'),
};

/// Merged transactions + transfer legs for one account, newest first —
/// feeds the Account Detail log (a single reactive stream instead of
/// juggling two providers in the UI).
final accountLedgerProvider = StreamProvider.family<List<LedgerEntry>, int>((
  ref,
  accountId,
) {
  final db = ref.watch(databaseProvider);
  final query = db.customSelect(
    _ledgerSql,
    variables: [
      Variable.withInt(accountId),
      Variable.withInt(accountId),
      Variable.withInt(accountId),
    ],
    readsFrom: {db.transactions, db.categories, db.transfers, db.accounts},
  ).map(
    (row) => LedgerEntry(
      kind: _parseKind(row.read<String>('kind')),
      id: row.read<int>('id'),
      date: row.read<DateTime>('date'),
      signType: row.read<String>('sign_type'),
      amount: row.read<int>('amount'),
      iconKey: row.readNullable<String>('icon'),
      iconColor: row.readNullable<int>('color'),
      title: row.read<String>('title'),
      note: row.readNullable<String>('note'),
    ),
  );
  return query.watch();
});

final transferByIdProvider = StreamProvider.family<Transfer?, int>((
  ref,
  id,
) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.transfers,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();
});

class TransferRepository {
  TransferRepository(this._db);
  final AppDatabase _db;

  Future<int> create(TransfersCompanion entry) {
    return _db.into(_db.transfers).insert(entry);
  }

  Future<bool> update(Transfer transfer) {
    return _db.update(_db.transfers).replace(transfer);
  }

  Future<void> delete(int transferId) {
    return (_db.delete(
      _db.transfers,
    )..where((t) => t.id.equals(transferId))).go();
  }
}

final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  return TransferRepository(ref.watch(databaseProvider));
});
