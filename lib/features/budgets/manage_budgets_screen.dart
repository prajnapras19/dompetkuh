import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../db/database.dart';
import '../../providers/budget_providers.dart';
import '../../providers/currency_providers.dart';
import '../../utils/formatters.dart';
import '../../widgets/icon_tile.dart';
import 'budget_form_screen.dart';

/// No FAB here — "Add Budget" lives in the home tab's center speed-dial
/// menu, so a second entry point here would just be redundant.
class ManageBudgetsScreen extends StatefulWidget {
  const ManageBudgetsScreen({super.key});

  @override
  State<ManageBudgetsScreen> createState() => _ManageBudgetsScreenState();
}

class _ManageBudgetsScreenState extends State<ManageBudgetsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1),
                  ),
                ),
                Text(DateFormat('MMMM yyyy').format(_month)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month + 1),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final budgetsAsync = ref.watch(allBudgetsProvider);
                return budgetsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (budgets) {
                    if (budgets.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No budgets yet. Use the pencil button below to '
                            'set a monthly amount for something (e.g. Food, '
                            'Bali Trip) — no alerts, just spent-vs-allocated '
                            'tracking, and a tag you can put on any '
                            'transaction.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: budgets.length,
                      itemBuilder: (context, index) =>
                          _BudgetRow(budget: budgets[index], month: _month),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetRow extends ConsumerWidget {
  final Budget budget;
  final DateTime month;
  const _BudgetRow({required this.budget, required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archived = budget.archivedAt != null;
    final currencyAsync = budget.currencyId == null
        ? null
        : ref.watch(currencyByIdProvider(budget.currencyId!));
    final spentAsync = ref.watch(
      budgetSpentInMonthProvider((budgetId: budget.id, month: month)),
    );

    return ListTile(
      leading: IconTile(iconKey: budget.icon, colorValue: budget.color),
      title: Text(
        budget.name,
        style: archived
            ? const TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Colors.grey,
              )
            : null,
      ),
      subtitle: currencyAsync?.when(
        loading: () => null,
        error: (_, _) => null,
        data: (currency) {
          if (currency == null) return null;
          return spentAsync.when(
            loading: () => const Text('…'),
            error: (_, _) => null,
            data: (spent) {
              final remaining = budget.monthlyAmount - spent;
              // A Row here reliably overflowed on-device once amounts got
              // long — two short lines wrap safely instead.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${Money.formatDisplay(spent, currency)} of '
                    '${Money.formatDisplay(budget.monthlyAmount, currency)}',
                  ),
                  Text(
                    'Remaining: ${Money.formatDisplay(remaining, currency)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              );
            },
          );
        },
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) =>
            _handleAction(context, ref, budget.id, archived, action),
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(
            value: archived ? 'unarchive' : 'archive',
            child: Text(archived ? 'Unarchive' : 'Archive'),
          ),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BudgetFormScreen(budget: budget)),
        );
      },
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    int budgetId,
    bool archived,
    String action,
  ) async {
    final repo = ref.read(budgetRepositoryProvider);
    switch (action) {
      case 'edit':
        final b = await ref.read(budgetByIdProvider(budgetId).future);
        if (b != null && context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BudgetFormScreen(budget: b)),
          );
        }
      case 'archive':
        await repo.archive(budgetId);
      case 'unarchive':
        await repo.unarchive(budgetId);
      case 'delete':
        final inUse = await repo.isInUse(budgetId);
        if (inUse) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'This budget is used by a transaction — archive it instead.',
                ),
              ),
            );
          }
          return;
        }
        await repo.delete(budgetId);
    }
  }
}
