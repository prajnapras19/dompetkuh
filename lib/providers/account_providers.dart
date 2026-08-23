import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../models/account_summary.dart';
import 'database_provider.dart';

/// Per-account balance, computed (not stored) as:
///   initialBalance + Σ(in) - Σ(out) + Σ(transfers in) - Σ(transfers out)
/// Kept as one raw SQL expression (correlated to the `a` alias) so it's
/// reactive to inserts/edits/deletes on transactions and transfers without
/// any manual cache invalidation.
const _balanceExpr = '''
  (a.initial_balance
  + COALESCE((SELECT SUM(amount) FROM transactions WHERE account_id = a.id AND type = 'in'), 0)
  - COALESCE((SELECT SUM(amount) FROM transactions WHERE account_id = a.id AND type = 'out'), 0)
  + COALESCE((SELECT SUM(to_amount) FROM transfers WHERE to_account_id = a.id), 0)
  - COALESCE((SELECT SUM(from_amount) FROM transfers WHERE from_account_id = a.id), 0))
''';

const _accountCurrencySelect = '''
  SELECT
    a.id AS a_id, a.name AS a_name, a.icon AS a_icon, a.color AS a_color,
    a.currency_id AS a_currency_id, a.initial_balance AS a_initial_balance,
    a.created_at AS a_created_at, a.archived_at AS a_archived_at,
    a.sort_order AS a_sort_order,
    c.id AS c_id, c.code AS c_code, c.name AS c_name, c.symbol AS c_symbol,
    c.decimal_places AS c_decimal_places, c.subunit_name AS c_subunit_name,
    c.symbol_before_amount AS c_symbol_before_amount, c.is_preset AS c_is_preset,
    c.sort_order AS c_sort_order, c.archived_at AS c_archived_at,
    $_balanceExpr AS balance
  FROM accounts a
  INNER JOIN currencies c ON c.id = a.currency_id
''';

AccountSummary _readAccountSummary(QueryRow row) {
  final account = Account(
    id: row.read<int>('a_id'),
    name: row.read<String>('a_name'),
    icon: row.readNullable<String>('a_icon'),
    color: row.readNullable<int>('a_color'),
    currencyId: row.read<int>('a_currency_id'),
    initialBalance: row.read<int>('a_initial_balance'),
    createdAt: row.read<DateTime>('a_created_at'),
    archivedAt: row.readNullable<DateTime>('a_archived_at'),
    sortOrder: row.read<int>('a_sort_order'),
  );
  final currency = Currency(
    id: row.read<int>('c_id'),
    code: row.read<String>('c_code'),
    name: row.read<String>('c_name'),
    symbol: row.read<String>('c_symbol'),
    decimalPlaces: row.read<int>('c_decimal_places'),
    subunitName: row.readNullable<String>('c_subunit_name'),
    symbolBeforeAmount: row.read<bool>('c_symbol_before_amount'),
    isPreset: row.read<bool>('c_is_preset'),
    sortOrder: row.read<int>('c_sort_order'),
    archivedAt: row.readNullable<DateTime>('c_archived_at'),
  );
  return AccountSummary(
    account: account,
    currency: currency,
    balance: row.read<int>('balance'),
  );
}

/// All non-archived accounts with their currency and live balance, ordered
/// for the Accounts Overview screen.
final accountSummariesProvider = StreamProvider<List<AccountSummary>>((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.customSelect(
    '$_accountCurrencySelect WHERE a.archived_at IS NULL ORDER BY a.sort_order, a.name',
    readsFrom: {db.accounts, db.currencies, db.transactions, db.transfers},
  ).map(_readAccountSummary);
  return query.watch();
});

final accountSummaryProvider = StreamProvider.family<AccountSummary?, int>((
  ref,
  accountId,
) {
  final db = ref.watch(databaseProvider);
  final query = db.customSelect(
    '$_accountCurrencySelect WHERE a.id = ?',
    variables: [Variable.withInt(accountId)],
    readsFrom: {db.accounts, db.currencies, db.transactions, db.transfers},
  ).map(_readAccountSummary);
  return query.watchSingleOrNull();
});

/// Total balance across all accounts sharing one currency (the "Total" row
/// only makes sense per-currency, per the plan's no-blended-net-worth rule).
final totalBalanceByCurrencyProvider = StreamProvider.family<int, int>((
  ref,
  currencyId,
) {
  final db = ref.watch(databaseProvider);
  final query = db.customSelect(
    '''
    SELECT COALESCE(SUM($_balanceExpr), 0) AS total
    FROM accounts a
    WHERE a.currency_id = ? AND a.archived_at IS NULL
    ''',
    variables: [Variable.withInt(currencyId)],
    readsFrom: {db.accounts, db.transactions, db.transfers},
  ).map((row) => row.read<int>('total'));
  return query.watchSingle();
});

class AccountRepository {
  AccountRepository(this._db);
  final AppDatabase _db;

  Future<int> create(AccountsCompanion entry) {
    return _db.into(_db.accounts).insert(entry);
  }

  Future<bool> update(Account account) {
    return _db.update(_db.accounts).replace(account);
  }

  Future<bool> hasEntries(int accountId) async {
    final txnCount = await (_db.selectOnly(_db.transactions)
          ..addColumns([_db.transactions.id.count()])
          ..where(_db.transactions.accountId.equals(accountId)))
        .map((row) => row.read(_db.transactions.id.count()) ?? 0)
        .getSingle();
    if (txnCount > 0) return true;

    final transferCount = await (_db.selectOnly(_db.transfers)
          ..addColumns([_db.transfers.id.count()])
          ..where(
            _db.transfers.fromAccountId.equals(accountId) |
                _db.transfers.toAccountId.equals(accountId),
          ))
        .map((row) => row.read(_db.transfers.id.count()) ?? 0)
        .getSingle();
    return transferCount > 0;
  }

  Future<void> archive(int accountId) {
    return (_db.update(_db.accounts)..where((a) => a.id.equals(accountId)))
        .write(AccountsCompanion(archivedAt: Value(DateTime.now())));
  }

  Future<void> delete(int accountId) {
    return (_db.delete(_db.accounts)..where((a) => a.id.equals(accountId)))
        .go();
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(databaseProvider));
});
