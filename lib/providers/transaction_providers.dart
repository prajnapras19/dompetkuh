import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../models/global_transaction_entry.dart';
import '../models/transaction_entry.dart';
import 'database_provider.dart';

/// All transactions for one account, newest first, joined with category —
/// feeds the Account Detail log.
final transactionsForAccountProvider =
    StreamProvider.family<List<TransactionEntry>, int>((ref, accountId) {
      final db = ref.watch(databaseProvider);
      final query = db.select(db.transactions).join([
        innerJoin(
          db.categories,
          db.categories.id.equalsExp(db.transactions.categoryId),
        ),
      ])
        ..where(db.transactions.accountId.equals(accountId))
        ..orderBy([OrderingTerm.desc(db.transactions.date)]);

      return query.watch().map(
        (rows) => rows
            .map(
              (row) => TransactionEntry(
                transaction: row.readTable(db.transactions),
                category: row.readTable(db.categories),
              ),
            )
            .toList(),
      );
    });

/// All transactions across every account within one calendar month, newest
/// first, joined with category + account + currency — feeds the home
/// Transactions tab. [month] should have day=1 (year/month only matter).
final transactionsInMonthProvider =
    StreamProvider.family<List<GlobalTransactionEntry>, DateTime>((
      ref,
      month,
    ) {
      final db = ref.watch(databaseProvider);
      final start = DateTime(month.year, month.month);
      final end = DateTime(month.year, month.month + 1);

      final query = db.select(db.transactions).join([
        innerJoin(
          db.categories,
          db.categories.id.equalsExp(db.transactions.categoryId),
        ),
        innerJoin(
          db.accounts,
          db.accounts.id.equalsExp(db.transactions.accountId),
        ),
        innerJoin(
          db.currencies,
          db.currencies.id.equalsExp(db.accounts.currencyId),
        ),
      ])
        ..where(
          db.transactions.date.isBiggerOrEqualValue(start) &
              db.transactions.date.isSmallerThanValue(end),
        )
        ..orderBy([OrderingTerm.desc(db.transactions.date)]);

      return query.watch().map(
        (rows) => rows
            .map(
              (row) => GlobalTransactionEntry(
                transaction: row.readTable(db.transactions),
                category: row.readTable(db.categories),
                account: row.readTable(db.accounts),
                currency: row.readTable(db.currencies),
              ),
            )
            .toList(),
      );
    });

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
