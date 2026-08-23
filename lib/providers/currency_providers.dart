import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import 'database_provider.dart';

/// All non-archived currencies, sorted for pickers/lists.
final activeCurrenciesProvider = StreamProvider<List<Currency>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.currencies)
        ..where((c) => c.archivedAt.isNull())
        ..orderBy([
          (c) => OrderingTerm(expression: c.sortOrder),
          (c) => OrderingTerm(expression: c.name),
        ]))
      .watch();
});

/// All currencies including archived ones, for the Manage Currencies screen.
final allCurrenciesProvider = StreamProvider<List<Currency>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.currencies)
        ..orderBy([
          (c) => OrderingTerm(expression: c.sortOrder),
          (c) => OrderingTerm(expression: c.name),
        ]))
      .watch();
});

final currencyByIdProvider = StreamProvider.family<Currency?, int>((
  ref,
  id,
) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.currencies,
  )..where((c) => c.id.equals(id))).watchSingleOrNull();
});

class CurrencyRepository {
  CurrencyRepository(this._db);
  final AppDatabase _db;

  Future<int> create(CurrenciesCompanion entry) {
    return _db.into(_db.currencies).insert(entry);
  }

  Future<bool> update(Currency currency) {
    return _db.update(_db.currencies).replace(currency);
  }

  /// True if any account still references this currency — callers should
  /// block hard delete and offer archive instead.
  Future<bool> isInUse(int currencyId) async {
    final count = await (_db.selectOnly(_db.accounts)
          ..addColumns([_db.accounts.id.count()])
          ..where(_db.accounts.currencyId.equals(currencyId)))
        .map((row) => row.read(_db.accounts.id.count()) ?? 0)
        .getSingle();
    return count > 0;
  }

  Future<void> archive(int currencyId) {
    return (_db.update(_db.currencies)..where((c) => c.id.equals(currencyId)))
        .write(CurrenciesCompanion(archivedAt: Value(DateTime.now())));
  }

  Future<void> unarchive(int currencyId) {
    return (_db.update(_db.currencies)..where((c) => c.id.equals(currencyId)))
        .write(const CurrenciesCompanion(archivedAt: Value(null)));
  }

  Future<void> delete(int currencyId) {
    return (_db.delete(
      _db.currencies,
    )..where((c) => c.id.equals(currencyId))).go();
  }
}

final currencyRepositoryProvider = Provider<CurrencyRepository>((ref) {
  return CurrencyRepository(ref.watch(databaseProvider));
});
