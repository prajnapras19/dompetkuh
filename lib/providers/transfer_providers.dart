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

/// Builds ` AND column NOT IN (?, ?, ...)`, appending placeholders'
/// variables to [variables] — empty [excluded] means no restriction, so no
/// clause is added at all (matching the filter screen's "all checked by
/// default" checklists).
String _excludeClause(
  String column,
  Set<int> excluded,
  List<Variable> variables,
) {
  if (excluded.isEmpty) return '';
  variables.addAll(excluded.map(Variable.withInt));
  final placeholders = List.filled(excluded.length, '?').join(', ');
  return ' AND $column NOT IN ($placeholders)';
}

/// Filters for [globalLedgerProvider]. Each `excluded*Ids` set is empty by
/// default (nothing excluded, matching the filter screen's checklists which
/// start all-checked) — matches the reference app's Filter screen model of
/// unchecking items to exclude them, rather than picking one to include.
/// [start]/[end] bound the date range (both null = all time, [end]
/// exclusive). Category/Budget exclusion only ever applies to transactions
/// (transfers have neither by design — see Transfers table rationale in
/// CLAUDE.md); [includeTransfers] is a separate toggle for them instead,
/// since there's no sensible per-category equivalent for a transfer leg.
/// [onlyCategoryId]/[onlyCurrencyId] are a separate hard `= ?` pin (not part
/// of the exclude checklists) used only by Reports' category drill-down —
/// "show just this one category" is a different intent than "exclude a few
/// from the list", and computing it as a checklist exclusion would need the
/// full category list just to build the complement.
typedef LedgerFilter = ({
  DateTime? start,
  DateTime? end,
  Set<int> excludedAccountIds,
  Set<int> excludedCategoryIds,
  Set<int> excludedBudgetIds,
  Set<int> excludedCurrencyIds,
  bool includeTransfers,
  int? onlyCategoryId,
  int? onlyCurrencyId,
});

/// All transactions + transfer legs across every account within a date
/// range, newest first, optionally filtered — feeds the home Transactions
/// tab.
final globalLedgerProvider =
    StreamProvider.family<List<GlobalLedgerEntry>, LedgerFilter>((
      ref,
      filter,
    ) {
      final db = ref.watch(databaseProvider);

      final variables = <Variable>[];
      final sql = StringBuffer();

      final txnWhere = StringBuffer('1 = 1');
      if (filter.start != null) {
        txnWhere.write(' AND t.date >= ?');
        variables.add(Variable.withDateTime(filter.start!));
      }
      if (filter.end != null) {
        txnWhere.write(' AND t.date < ?');
        variables.add(Variable.withDateTime(filter.end!));
      }
      txnWhere.write(
        _excludeClause('t.account_id', filter.excludedAccountIds, variables),
      );
      txnWhere.write(
        _excludeClause(
          't.category_id',
          filter.excludedCategoryIds,
          variables,
        ),
      );
      if (filter.excludedBudgetIds.isNotEmpty) {
        variables.addAll(filter.excludedBudgetIds.map(Variable.withInt));
        final placeholders = List.filled(
          filter.excludedBudgetIds.length,
          '?',
        ).join(', ');
        txnWhere.write(
          ' AND (t.budget_id IS NULL OR t.budget_id NOT IN ($placeholders))',
        );
      }
      txnWhere.write(
        _excludeClause('cur.id', filter.excludedCurrencyIds, variables),
      );
      if (filter.onlyCategoryId != null) {
        txnWhere.write(' AND t.category_id = ?');
        variables.add(Variable.withInt(filter.onlyCategoryId!));
      }
      if (filter.onlyCurrencyId != null) {
        txnWhere.write(' AND cur.id = ?');
        variables.add(Variable.withInt(filter.onlyCurrencyId!));
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

      // A category pin means "only this category's transactions" — transfers
      // have no category, so they can never match and are skipped entirely
      // (same as when excludedCategoryIds made a category filter active
      // before this typedef grew the separate onlyCategoryId pin).
      if (filter.includeTransfers && filter.onlyCategoryId == null) {
        for (final (kind, sign, amountCol, joinCol, otherCol, otherAlias, label)
            in [
              (
                'transfer_out',
                'out',
                'from_amount',
                'from_account_id',
                'to_account_id',
                'dest',
                'Transfer to ',
              ),
              (
                'transfer_in',
                'in',
                'to_amount',
                'to_account_id',
                'from_account_id',
                'src',
                'Transfer from ',
              ),
            ]) {
          final transferWhere = StringBuffer('1 = 1');
          if (filter.start != null) {
            transferWhere.write(' AND tr.date >= ?');
            variables.add(Variable.withDateTime(filter.start!));
          }
          if (filter.end != null) {
            transferWhere.write(' AND tr.date < ?');
            variables.add(Variable.withDateTime(filter.end!));
          }
          transferWhere.write(
            _excludeClause('a.id', filter.excludedAccountIds, variables),
          );
          transferWhere.write(
            _excludeClause('cur.id', filter.excludedCurrencyIds, variables),
          );
          if (filter.onlyCurrencyId != null) {
            transferWhere.write(' AND cur.id = ?');
            variables.add(Variable.withInt(filter.onlyCurrencyId!));
          }

          sql.write('''
            UNION ALL
            SELECT '$kind' AS kind, tr.id AS id, tr.date AS date, '$sign' AS sign_type,
              tr.$amountCol AS amount, 'transfer' AS icon, NULL AS color,
              '$label' || $otherAlias.name AS title, tr.note AS note, $_globalLedgerColumns
            FROM transfers tr
            INNER JOIN accounts a ON a.id = tr.$joinCol
            INNER JOIN accounts $otherAlias ON $otherAlias.id = tr.$otherCol
            INNER JOIN currencies cur ON cur.id = a.currency_id
            WHERE $transferWhere
          ''');
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

/// All transactions + transfer legs (any account, any time) whose note
/// contains [query] (case-insensitive substring, matching SQLite's default
/// ASCII-insensitive LIKE) — feeds the Transactions tab's search screen,
/// matching the reference app's "Cari berdasarkan catatan" (search by note)
/// box. An empty query returns no results without querying, same as the
/// reference app showing nothing until you start typing — entries with no
/// note can never match, which is expected: there's nothing to search.
final globalLedgerSearchProvider =
    StreamProvider.family<List<GlobalLedgerEntry>, String>((ref, query) {
      final trimmed = query.trim();
      if (trimmed.isEmpty) return Stream.value(const []);

      final db = ref.watch(databaseProvider);
      final likePattern = '%$trimmed%';

      final sql =
          '''
        SELECT 'transaction' AS kind, t.id AS id, t.date AS date, t.type AS sign_type,
          t.amount AS amount, c.icon AS icon, c.color AS color, c.name AS title,
          t.note AS note, $_globalLedgerColumns
        FROM transactions t
        INNER JOIN categories c ON c.id = t.category_id
        INNER JOIN accounts a ON a.id = t.account_id
        INNER JOIN currencies cur ON cur.id = a.currency_id
        WHERE t.note LIKE ?
        UNION ALL
        SELECT 'transfer_out' AS kind, tr.id AS id, tr.date AS date, 'out' AS sign_type,
          tr.from_amount AS amount, 'transfer' AS icon, NULL AS color,
          'Transfer to ' || dest.name AS title, tr.note AS note, $_globalLedgerColumns
        FROM transfers tr
        INNER JOIN accounts a ON a.id = tr.from_account_id
        INNER JOIN accounts dest ON dest.id = tr.to_account_id
        INNER JOIN currencies cur ON cur.id = a.currency_id
        WHERE tr.note LIKE ?
        UNION ALL
        SELECT 'transfer_in' AS kind, tr.id AS id, tr.date AS date, 'in' AS sign_type,
          tr.to_amount AS amount, 'transfer' AS icon, NULL AS color,
          'Transfer from ' || src.name AS title, tr.note AS note, $_globalLedgerColumns
        FROM transfers tr
        INNER JOIN accounts a ON a.id = tr.to_account_id
        INNER JOIN accounts src ON src.id = tr.from_account_id
        INNER JOIN currencies cur ON cur.id = a.currency_id
        WHERE tr.note LIKE ?
        ORDER BY date DESC
      ''';

      final stmt = db.customSelect(
        sql,
        variables: [
          Variable.withString(likePattern),
          Variable.withString(likePattern),
          Variable.withString(likePattern),
        ],
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
      return stmt.watch();
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
