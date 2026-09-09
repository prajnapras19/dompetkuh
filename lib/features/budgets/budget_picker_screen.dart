import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/budget_providers.dart';
import '../../widgets/icon_tile.dart';
import 'budget_form_screen.dart';

/// Sentinel returned by [BudgetPickerScreen] for its "None" entry — Budgets
/// are an optional tag, and this needs to read as a distinct, explicit
/// choice rather than "the user backed out without picking anything" (which
/// pops with a real `null`). Budget ids are Drift autoincrement primary
/// keys, so 0 is never a real one.
const noneBudgetId = 0;

/// Full-page budget picker (an app-specific field with no reference-app
/// equivalent, styled to match the Category/Account pickers) — only shows
/// budgets in [currencyId], since a budget's "spent" total only stays
/// meaningful if every tagged transaction shares its currency.
class BudgetPickerScreen extends ConsumerWidget {
  final int currencyId;

  const BudgetPickerScreen({super.key, required this.currencyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(activeBudgetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Budget'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _quickAdd(context),
          ),
        ],
      ),
      body: budgetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allBudgets) {
          final budgets =
              allBudgets.where((b) => b.currencyId == currencyId).toList()
                ..sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                );
          return ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.not_interested, color: Colors.grey),
                title: const Text('None'),
                onTap: () => Navigator.of(context).pop(noneBudgetId),
              ),
              if (budgets.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No budgets in this currency yet — tap + to add one.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final budget in budgets)
                ListTile(
                  leading: IconTile(
                    iconKey: budget.icon,
                    colorValue: budget.color,
                  ),
                  title: Text(budget.name),
                  onTap: () => Navigator.of(context).pop(budget.id),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _quickAdd(BuildContext context) async {
    final newId = await Navigator.of(
      context,
    ).push<int>(MaterialPageRoute(builder: (_) => const BudgetFormScreen()));
    if (newId != null && context.mounted) Navigator.of(context).pop(newId);
  }
}
