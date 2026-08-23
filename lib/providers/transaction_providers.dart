import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import 'database_provider.dart';

final transactionByIdProvider = StreamProvider.family<Transaction?, int>((
  ref,
  id,
) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.transactions,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();
});

class TransactionRepository {
  TransactionRepository(this._db);
  final AppDatabase _db;

  Future<int> create(TransactionsCompanion entry) {
    return _db.into(_db.transactions).insert(entry);
  }

  Future<bool> update(Transaction transaction) {
    return _db.update(_db.transactions).replace(transaction);
  }

  Future<void> delete(int transactionId) {
    return (_db.delete(
      _db.transactions,
    )..where((t) => t.id.equals(transactionId))).go();
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(databaseProvider));
});
