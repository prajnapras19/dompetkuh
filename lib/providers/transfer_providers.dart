import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../models/global_ledger_entry.dart';
import '../models/ledger_entry.dart';
import 'database_provider.dart';

LedgerKind _parseKind(String raw) => switch (raw) {
  'transaction' => LedgerKind.transaction,
  'transfer_out' => LedgerKind.transferOut,
  'transfer_in' => LedgerKind.transferIn,
  _ => throw ArgumentError('Unknown ledger kind: $raw'),
};

const _globalLedgerColumns = '''
    a.id AS account_id, a.name AS account_name, a.icon AS account_icon,
    a.color AS account_color, a.currency_id AS account_currency_id,
    a.initial_balance AS account_initial_balance,
    a.created_at AS account_created_at, a.archived_at AS account_archived_at,
    a.sort_order AS account_sort_order,
    cur.id AS cur_id, cur.code AS cur_code, cur.name AS cur_name,
    cur.symbol AS cur_symbol, cur.decimal_places AS cur_decimal_places,
    cur.subunit_name AS cur_subunit_name,
    cur.symbol_before_amount AS cur_symbol_before_amount,
    cur.is_preset AS cur_is_preset, cur.sort_order AS cur_sort_order,
    cur.archived_at AS cur_archived_at
''';

Account _readLedgerAccount(QueryRow row) => Account(
  id: row.read<int>('account_id'),
  name: row.read<String>('account_name'),
  icon: row.readNullable<String>('account_icon'),
  color: row.readNullable<int>('account_color'),
  currencyId: row.read<int>('account_currency_id'),
  initialBalance: row.read<int>('account_initial_balance'),
  createdAt: row.read<DateTime>('account_created_at'),
  archivedAt: row.readNullable<DateTime>('account_archived_at'),
  sortOrder: row.read<int>('account_sort_order'),
);

Currency _readLedgerCurrency(QueryRow row) => Currency(
  id: row.read<int>('cur_id'),
  code: row.read<String>('cur_code'),
  name: row.read<String>('cur_name'),
  symbol: row.read<String>('cur_symbol'),
  decimalPlaces: row.read<int>('cur_decimal_places'),
  subunitName: row.readNullable<String>('cur_subunit_name'),
  symbolBeforeAmount: row.read<bool>('cur_symbol_before_amount'),
  isPreset: row.read<bool>('cur_is_preset'),
  sortOrder: row.read<int>('cur_sort_order'),
  archivedAt: row.readNullable<DateTime>('cur_archived_at'),
);

/// Filters for [globalLedgerInMonthProvider]. categoryId/budgetId exclude
/// transfers entirely (transfers have neither) — accountId/currencyId still
/// include transfers, matching either leg's account/currency.
typedef LedgerFilter = ({
  DateTime month,
  int? accountId,
  int? categoryId,
  int? budgetId,
  int? currencyId,
});

/// All transactions + transfer legs across every account within one
/// calendar month, newest first, optionally filtered — feeds the home
/// Transactions tab. [filter.month] should have day=1.
final globalLedgerInMonthProvider =
    StreamProvider.family<List<GlobalLedgerEntry>, LedgerFilter>((
      ref,
      filter,
    ) {
      final db = ref.watch(databaseProvider);
      final start = DateTime(filter.month.year, filter.month.month);
      final end = DateTime(filter.month.year, filter.month.month + 1);
      final includeTransfers = filter.categoryId == null && filter.budgetId == null;

      final variables = <Variable>[];
      final sql = StringBuffer();

      final txnWhere = StringBuffer('t.date >= ? AND t.date < ?');
      variables.addAll([Variable.withDateTime(start), Variable.withDateTime(end)]);
      if (filter.accountId != null) {
        txnWhere.write(' AND t.account_id = ?');
        variables.add(Variable.withInt(filter.accountId!));
      }
      if (filter.categoryId != null) {
        txnWhere.write(' AND t.category_id = ?');
        variables.add(Variable.withInt(filter.categoryId!));
      }
      if (filter.budgetId != null) {
        txnWhere.write(' AND t.budget_id = ?');
        variables.add(Variable.withInt(filter.budgetId!));
      }
      if (filter.currencyId != null) {
        txnWhere.write(' AND cur.id = ?');
        variables.add(Variable.withInt(filter.currencyId!));
      }

      sql.write('''
        SELECT 'transaction' AS kind, t.id AS id, t.date AS date, t.type AS sign_type,
          t.amount AS amount, c.icon AS icon, c.color AS color, c.name AS title,
          t.note AS note, $_globalLedgerColumns
        FROM transactions t
        INNER JOIN categories c ON c.id = t.category_id
        INNER JOIN accounts a ON a.id = t.account_id
        INNER JOIN currencies cur ON cur.id = a.currency_id
        WHERE $txnWhere
      ''');

      if (includeTransfers) {
        final transferClause = StringBuffer();
        if (filter.accountId != null) transferClause.write(' AND a.id = ?');
        if (filter.currencyId != null) transferClause.write(' AND cur.id = ?');

        sql.write('''
          UNION ALL
          SELECT 'transfer_out' AS kind, tr.id AS id, tr.date AS date, 'out' AS sign_type,
            tr.from_amount AS amount, 'transfer' AS icon, NULL AS color,
            'Transfer to ' || dest.name AS title, tr.note AS note, $_globalLedgerColumns
          FROM transfers tr
          INNER JOIN accounts a ON a.id = tr.from_account_id
          INNER JOIN accounts dest ON dest.id = tr.to_account_id
          INNER JOIN currencies cur ON cur.id = a.currency_id
          WHERE tr.date >= ? AND tr.date < ?$transferClause
        ''');
        variables.addAll([
          Variable.withDateTime(start),
          Variable.withDateTime(end),
        ]);
        if (filter.accountId != null) {
          variables.add(Variable.withInt(filter.accountId!));
        }
        if (filter.currencyId != null) {
          variables.add(Variable.withInt(filter.currencyId!));
        }

        sql.write('''
          UNION ALL
          SELECT 'transfer_in' AS kind, tr.id AS id, tr.date AS date, 'in' AS sign_type,
            tr.to_amount AS amount, 'transfer' AS icon, NULL AS color,
            'Transfer from ' || src.name AS title, tr.note AS note, $_globalLedgerColumns
          FROM transfers tr
          INNER JOIN accounts a ON a.id = tr.to_account_id
          INNER JOIN accounts src ON src.id = tr.from_account_id
          INNER JOIN currencies cur ON cur.id = a.currency_id
          WHERE tr.date >= ? AND tr.date < ?$transferClause
        ''');
        variables.addAll([
          Variable.withDateTime(start),
          Variable.withDateTime(end),
        ]);
        if (filter.accountId != null) {
          variables.add(Variable.withInt(filter.accountId!));
        }
        if (filter.currencyId != null) {
          variables.add(Variable.withInt(filter.currencyId!));
        }
      }

      sql.write(' ORDER BY date DESC');

      final query = db.customSelect(
        sql.toString(),
        variables: variables,
        readsFrom: {
          db.transactions,
          db.categories,
          db.accounts,
          db.currencies,
          db.transfers,
        },
      ).map(
        (row) => GlobalLedgerEntry(
          entry: LedgerEntry(
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
          account: _readLedgerAccount(row),
          currency: _readLedgerCurrency(row),
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
