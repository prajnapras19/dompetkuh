import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/database.dart';
import '../../providers/account_providers.dart';
import '../../providers/budget_providers.dart';
import '../../providers/category_providers.dart';
import '../../providers/currency_providers.dart';
import '../../utils/report_period.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/icon_tile.dart';

/// Result of [TransactionFilterScreen] — the caller only sees this after
/// FILTER is tapped; back/cancel returns null (no change).
typedef TransactionFilterResult = ({
  ReportPeriod period,
  Set<int> excludedAccountIds,
  Set<int> excludedCategoryIds,
  Set<int> excludedBudgetIds,
  Set<int> excludedCurrencyIds,
  bool includeTransfers,
});

/// Full-page filter matching the reference app's Filter screen: a
/// Semua/Harian/Bulanan/Tahunan/Sesuaikan period chip row, then Account and
/// Category as checklists (every item checked by default — uncheck to
/// exclude it, rather than picking one to include). Currency and Budget are
/// app-specific extensions the reference app has no equivalent for (it's
/// single-currency with no budgets), styled the same way for consistency.
/// "Include transfers" is a separate switch rather than a checklist entry,
/// since transfers have no category/budget for a checkbox to attach to.
class TransactionFilterScreen extends ConsumerStatefulWidget {
  final ReportPeriod period;
  final Set<int> excludedAccountIds;
  final Set<int> excludedCategoryIds;
  final Set<int> excludedBudgetIds;
  final Set<int> excludedCurrencyIds;
  final bool includeTransfers;

  const TransactionFilterScreen({
    super.key,
    required this.period,
    required this.excludedAccountIds,
    required this.excludedCategoryIds,
    required this.excludedBudgetIds,
    required this.excludedCurrencyIds,
    required this.includeTransfers,
  });

  @override
  ConsumerState<TransactionFilterScreen> createState() =>
      _TransactionFilterScreenState();
}

class _TransactionFilterScreenState
    extends ConsumerState<TransactionFilterScreen> {
  late ReportPeriod _period = widget.period;
  late final _excludedAccountIds = {...widget.excludedAccountIds};
  late final _excludedCategoryIds = {...widget.excludedCategoryIds};
  late final _excludedBudgetIds = {...widget.excludedBudgetIds};
  late final _excludedCurrencyIds = {...widget.excludedCurrencyIds};
  late bool _includeTransfers = widget.includeTransfers;

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountSummariesProvider);
    final categoriesInAsync = ref.watch(categoriesByTypeProvider(CategoryType.in_));
    final categoriesOutAsync = ref.watch(categoriesByTypeProvider(CategoryType.out));
    final currenciesAsync = ref.watch(activeCurrenciesProvider);
    final budgetsAsync = ref.watch(activeBudgetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Filter')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          const FormCaption('TIME RANGE'),
          _PeriodChipRow(
            period: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include transfers'),
            value: _includeTransfers,
            onChanged: (v) => setState(() => _includeTransfers = v),
          ),
          const Divider(height: 32),
          _SectionHeader(
            'ACCOUNT',
            ids: accountsAsync.valueOrNull?.map((a) => a.account.id),
            excluded: _excludedAccountIds,
            onChanged: () => setState(() {}),
          ),
          accountsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (accounts) {
              final sorted = [...accounts]..sort(
                (a, b) => a.account.name.toLowerCase().compareTo(
                  b.account.name.toLowerCase(),
                ),
              );
              return Column(
                children: [
                  for (final a in sorted)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.trailing,
                      secondary: IconTile(
                        iconKey: a.account.icon,
                        colorValue: a.account.color,
                        size: 36,
                      ),
                      title: Text(a.account.name),
                      value: !_excludedAccountIds.contains(a.account.id),
                      onChanged: (checked) => setState(() {
                        if (checked ?? true) {
                          _excludedAccountIds.remove(a.account.id);
                        } else {
                          _excludedAccountIds.add(a.account.id);
                        }
                      }),
                    ),
                ],
              );
            },
          ),
          const Divider(height: 32),
          const FormCaption('CATEGORY'),
          categoriesInAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (inCategories) => categoriesOutAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (outCategories) => Column(
                children: [
                  _SectionHeader(
                    'Income',
                    ids: inCategories.map((c) => c.id),
                    excluded: _excludedCategoryIds,
                    onChanged: () => setState(() {}),
                    sub: true,
                  ),
                  for (final c in inCategories) _categoryTile(c),
                  _SectionHeader(
                    'Expense',
                    ids: outCategories.map((c) => c.id),
                    excluded: _excludedCategoryIds,
                    onChanged: () => setState(() {}),
                    sub: true,
                  ),
                  for (final c in outCategories) _categoryTile(c),
                ],
              ),
            ),
          ),
          const Divider(height: 32),
          _SectionHeader(
            'CURRENCY',
            ids: currenciesAsync.valueOrNull?.map((c) => c.id),
            excluded: _excludedCurrencyIds,
            onChanged: () => setState(() {}),
          ),
          currenciesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (currencies) => Column(
              children: [
                for (final c in currencies)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.trailing,
                    title: Text('${c.code} — ${c.name}'),
                    value: !_excludedCurrencyIds.contains(c.id),
                    onChanged: (checked) => setState(() {
                      if (checked ?? true) {
                        _excludedCurrencyIds.remove(c.id);
                      } else {
                        _excludedCurrencyIds.add(c.id);
                      }
                    }),
                  ),
              ],
            ),
          ),
          const Divider(height: 32),
          _SectionHeader(
            'BUDGET',
            ids: budgetsAsync.valueOrNull?.map((b) => b.id),
            excluded: _excludedBudgetIds,
            onChanged: () => setState(() {}),
          ),
          budgetsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (budgets) {
              if (budgets.isEmpty) {
                return const Text(
                  'No budgets yet.',
                  style: TextStyle(color: Colors.grey),
                );
              }
              return Column(
                children: [
                  for (final b in budgets)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.trailing,
                      secondary: IconTile(
                        iconKey: b.icon,
                        colorValue: b.color,
                        size: 36,
                      ),
                      title: Text(b.name),
                      value: !_excludedBudgetIds.contains(b.id),
                      onChanged: (checked) => setState(() {
                        if (checked ?? true) {
                          _excludedBudgetIds.remove(b.id);
                        } else {
                          _excludedBudgetIds.add(b.id);
                        }
                      }),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop<TransactionFilterResult>((
              period: _period,
              excludedAccountIds: _excludedAccountIds,
              excludedCategoryIds: _excludedCategoryIds,
              excludedBudgetIds: _excludedBudgetIds,
              excludedCurrencyIds: _excludedCurrencyIds,
              includeTransfers: _includeTransfers,
            )),
            child: const Text('FILTER'),
          ),
        ],
      ),
    );
  }

  Widget _categoryTile(Category c) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.trailing,
      secondary: IconTile(iconKey: c.icon, colorValue: c.color, size: 36),
      title: Text(c.name),
      value: !_excludedCategoryIds.contains(c.id),
      onChanged: (checked) => setState(() {
        if (checked ?? true) {
          _excludedCategoryIds.remove(c.id);
        } else {
          _excludedCategoryIds.add(c.id);
        }
      }),
    );
  }
}

/// A checklist's title row with "Select all" / "Deselect all" shortcuts. The
/// filter state is exclude-based, so "Select all" clears the section's ids
/// from [excluded] and "Deselect all" adds them all. [ids] is null while the list is still loading,
/// which disables the shortcuts. [sub] styles it as a sub-section label
/// (Income/Expense inside Category) rather than a section caption.
class _SectionHeader extends StatelessWidget {
  final String title;
  final Iterable<int>? ids;
  final Set<int> excluded;
  final VoidCallback onChanged;
  final bool sub;

  const _SectionHeader(
    this.title, {
    required this.ids,
    required this.excluded,
    required this.onChanged,
    this.sub = false,
  });

  @override
  Widget build(BuildContext context) {
    final ids = this.ids?.toList();
    return Padding(
      padding: EdgeInsets.only(top: sub ? 4 : 0),
      child: Row(
        children: [
          Expanded(
            child: sub
                ? Text(
                    title.toUpperCase(),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  )
                : FormCaption(title),
          ),
          _action(
            'Select all',
            ids == null
                ? null
                : () {
                    excluded.removeAll(ids);
                    onChanged();
                  },
          ),
          _action(
            'Deselect all',
            ids == null
                ? null
                : () {
                    excluded.addAll(ids);
                    onChanged();
                  },
          ),
        ],
      ),
    );
  }

  Widget _action(String label, VoidCallback? onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _PeriodChipRow extends StatelessWidget {
  final ReportPeriod period;
  final ValueChanged<ReportPeriod> onChanged;
  const _PeriodChipRow({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(
            'All',
            period.type == ReportPeriodType.all,
            () => onChanged(ReportPeriod.all()),
          ),
          const SizedBox(width: 8),
          _chip(
            'Daily',
            period.type == ReportPeriodType.daily,
            () => onChanged(ReportPeriod.daily()),
          ),
          const SizedBox(width: 8),
          _chip(
            'Monthly',
            period.type == ReportPeriodType.monthly,
            () => onChanged(ReportPeriod.monthly()),
          ),
          const SizedBox(width: 8),
          _chip(
            'Yearly',
            period.type == ReportPeriodType.yearly,
            () => onChanged(ReportPeriod.yearly()),
          ),
          const SizedBox(width: 8),
          _chip(
            'Custom',
            period.type == ReportPeriodType.custom,
            () => _pickCustom(context),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 7)),
        end: now,
      ),
    );
    if (range != null) onChanged(ReportPeriod.custom(range.start, range.end));
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
