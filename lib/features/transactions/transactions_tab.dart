import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/global_ledger_entry.dart';
import '../../models/ledger_entry.dart';
import '../../providers/account_providers.dart';
import '../../providers/budget_providers.dart';
import '../../providers/category_providers.dart';
import '../../providers/currency_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../providers/transfer_providers.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/money_text.dart';
import '../transfers/add_transfer_screen.dart';
import 'transaction_detail_screen.dart';

/// Home tab: every transaction + transfer across all accounts for the
/// selected month, day-grouped, matching the reference app's Transaksi
/// screen. Per-currency income/expense/total summary (never blended across
/// currencies). Also reachable pushed (with a back button) from Reports'
/// category drill-down, via the initial* params.
class TransactionsTab extends ConsumerStatefulWidget {
  final DateTime? initialMonth;
  final int? initialAccountId;
  final int? initialCategoryId;
  final int? initialBudgetId;
  final int? initialCurrencyId;

  const TransactionsTab({
    super.key,
    this.initialMonth,
    this.initialAccountId,
    this.initialCategoryId,
    this.initialBudgetId,
    this.initialCurrencyId,
  });

  @override
  ConsumerState<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends ConsumerState<TransactionsTab> {
  late DateTime _month = widget.initialMonth != null
      ? DateTime(widget.initialMonth!.year, widget.initialMonth!.month)
      : DateTime(DateTime.now().year, DateTime.now().month);
  late int? _accountId = widget.initialAccountId;
  late int? _categoryId = widget.initialCategoryId;
  late int? _budgetId = widget.initialBudgetId;
  late int? _currencyId = widget.initialCurrencyId;

  bool get _hasFilter =>
      _accountId != null ||
      _categoryId != null ||
      _budgetId != null ||
      _currencyId != null;

  @override
  Widget build(BuildContext context) {
    final filter = (
      month: _month,
      accountId: _accountId,
      categoryId: _categoryId,
      budgetId: _budgetId,
      currencyId: _currencyId,
    );
    final entriesAsync = ref.watch(globalLedgerInMonthProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: Icon(_hasFilter ? Icons.filter_alt : Icons.filter_alt_outlined),
            color: _hasFilter ? Theme.of(context).colorScheme.primary : null,
            tooltip: 'Filter',
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          _MonthPager(
            month: _month,
            onChanged: (m) => setState(() => _month = m),
          ),
          if (_hasFilter)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _accountId = null;
                    _categoryId = null;
                    _budgetId = null;
                    _currencyId = null;
                  }),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Clear filter'),
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: entriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (entries) {
                if (entries.isEmpty) {
                  return const Center(
                    child: Text(
                      'No transactions match.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                final byCurrency = groupBy(
                  entries,
                  (GlobalLedgerEntry e) => e.currency.id,
                );
                final byDay = groupBy(
                  entries,
                  (GlobalLedgerEntry e) => DateTime(
                    e.entry.date.year,
                    e.entry.date.month,
                    e.entry.date.day,
                  ),
                );
                final days = byDay.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                return ListView(
                  children: [
                    for (final group in byCurrency.values)
                      _CurrencySummary(entries: group),
                    const SizedBox(height: 8),
                    for (final day in days)
                      _DaySection(day: day, entries: byDay[day]!),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FilterSheet(
        accountId: _accountId,
        categoryId: _categoryId,
        budgetId: _budgetId,
        currencyId: _currencyId,
      ),
    );
    if (result != null) {
      setState(() {
        _accountId = result.accountId;
        _categoryId = result.categoryId;
        _budgetId = result.budgetId;
        _currencyId = result.currencyId;
      });
    }
  }
}

typedef _FilterResult = ({
  int? accountId,
  int? categoryId,
  int? budgetId,
  int? currencyId,
});

class _FilterSheet extends ConsumerStatefulWidget {
  final int? accountId;
  final int? categoryId;
  final int? budgetId;
  final int? currencyId;

  const _FilterSheet({
    this.accountId,
    this.categoryId,
    this.budgetId,
    this.currencyId,
  });

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late int? _accountId = widget.accountId;
  late int? _categoryId = widget.categoryId;
  late int? _budgetId = widget.budgetId;
  late int? _currencyId = widget.currencyId;

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountSummariesProvider);
    final categoriesInAsync = ref.watch(categoriesByTypeProvider('in'));
    final categoriesOutAsync = ref.watch(categoriesByTypeProvider('out'));
    final budgetsAsync = ref.watch(activeBudgetsProvider);
    final currenciesAsync = ref.watch(activeCurrenciesProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter transactions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text('ACCOUNT', style: TextStyle(fontSize: 11, color: Colors.grey)),
            accountsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (accounts) => DropdownButtonFormField<int?>(
                initialValue: _accountId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('All accounts')),
                  for (final a in accounts)
                    DropdownMenuItem(
                      value: a.account.id,
                      child: Text('${a.account.name} (${a.currency.code})'),
                    ),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
            ),
            const SizedBox(height: 16),
            const Text('CATEGORY', style: TextStyle(fontSize: 11, color: Colors.grey)),
            categoriesInAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (inCategories) => categoriesOutAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (outCategories) {
                  final categories = [...inCategories, ...outCategories];
                  final valid = categories.any((c) => c.id == _categoryId);
                  return DropdownButtonFormField<int?>(
                    initialValue: valid ? _categoryId : null,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All categories'),
                      ),
                      for (final c in categories)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text('CURRENCY', style: TextStyle(fontSize: 11, color: Colors.grey)),
            currenciesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (currencies) => DropdownButtonFormField<int?>(
                initialValue: _currencyId,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All currencies'),
                  ),
                  for (final c in currencies)
                    DropdownMenuItem(value: c.id, child: Text(c.code)),
                ],
                onChanged: (v) => setState(() => _currencyId = v),
              ),
            ),
            const SizedBox(height: 16),
            const Text('BUDGET', style: TextStyle(fontSize: 11, color: Colors.grey)),
            budgetsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (budgets) {
                final valid = budgets.any((b) => b.id == _budgetId);
                return DropdownButtonFormField<int?>(
                  initialValue: valid ? _budgetId : null,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All budgets')),
                    for (final b in budgets)
                      DropdownMenuItem(value: b.id, child: Text(b.name)),
                  ],
                  onChanged: (v) => setState(() => _budgetId = v),
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop((
                      accountId: null,
                      categoryId: null,
                      budgetId: null,
                      currencyId: null,
                    )),
                    child: const Text('CLEAR'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop((
                      accountId: _accountId,
                      categoryId: _categoryId,
                      budgetId: _budgetId,
                      currencyId: _currencyId,
                    )),
                    child: const Text('APPLY'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthPager extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  const _MonthPager({required this.month, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
          ),
          Text(
            DateFormat('MMMM yyyy').format(month),
            style: const TextStyle(fontSize: 16),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
          ),
        ],
      ),
    );
  }
}

/// Income only counts plain 'in' transactions; transfers move money between
/// your own accounts so they're excluded from income/expense (they still
/// show up as line items below, just not summed into these totals).
class _CurrencySummary extends StatelessWidget {
  final List<GlobalLedgerEntry> entries;
  const _CurrencySummary({required this.entries});

  @override
  Widget build(BuildContext context) {
    final currency = entries.first.currency;
    final income = entries
        .where(
          (e) =>
              e.entry.kind == LedgerKind.transaction &&
              e.entry.signType == 'in',
        )
        .fold<int>(0, (sum, e) => sum + e.entry.amount);
    final expense = entries
        .where(
          (e) =>
              e.entry.kind == LedgerKind.transaction &&
              e.entry.signType == 'out',
        )
        .fold<int>(0, (sum, e) => sum + e.entry.amount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currency.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Income'),
              MoneyText(minorUnits: income, currency: currency, signType: 'in'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Expense'),
              MoneyText(
                minorUnits: expense,
                currency: currency,
                signType: 'out',
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
              MoneyText(
                minorUnits: income - expense,
                currency: currency,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DaySection extends ConsumerWidget {
  final DateTime day;
  final List<GlobalLedgerEntry> entries;
  const _DaySection({required this.day, required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyIds = entries.map((e) => e.currency.id).toSet();
    final singleCurrency = currencyIds.length == 1
        ? entries.first.currency
        : null;
    final net = singleCurrency == null
        ? null
        : entries
              .where((e) => e.entry.kind == LedgerKind.transaction)
              .fold<int>(
                0,
                (sum, e) =>
                    sum +
                    (e.entry.signType == 'in'
                        ? e.entry.amount
                        : -e.entry.amount),
              );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                DateFormat('d').format(day),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('EEEE').format(day)),
                    Text(
                      DateFormat('MMMM yyyy').format(day),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (net != null)
                MoneyText(minorUnits: net, currency: singleCurrency!),
            ],
          ),
        ),
        for (final global in entries)
          ListTile(
            leading: IconTile(
              iconKey: global.entry.iconKey,
              colorValue: global.entry.iconColor,
            ),
            title: Text(global.entry.title),
            subtitle: Text(
              global.entry.note?.isNotEmpty == true
                  ? '${global.account.name} · ${global.entry.note}'
                  : global.account.name,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MoneyText(
                  minorUnits: global.entry.amount,
                  currency: global.currency,
                  signType: global.entry.signType,
                ),
                Text(
                  DateFormat('HH:mm').format(global.entry.date),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            onTap: () => _openEntry(context, ref, global),
          ),
        const Divider(height: 24),
      ],
    );
  }

  Future<void> _openEntry(
    BuildContext context,
    WidgetRef ref,
    GlobalLedgerEntry global,
  ) async {
    if (global.entry.kind == LedgerKind.transaction) {
      final transaction = await ref.read(
        transactionByIdProvider(global.entry.id).future,
      );
      if (transaction != null && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                TransactionDetailScreen(entry: global, transaction: transaction),
          ),
        );
      }
    } else {
      final transfer = await ref.read(
        transferByIdProvider(global.entry.id).future,
      );
      if (transfer != null && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddTransferScreen(
              initialFromAccountId: global.account.id,
              transfer: transfer,
            ),
          ),
        );
      }
    }
  }
}
