import 'package:flutter/material.dart';

import '../budgets/budget_form_screen.dart';
import '../budgets/manage_budgets_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/add_transaction_screen.dart';
import '../transactions/transactions_tab.dart';
import '../transfers/add_transfer_screen.dart';

/// Outer navigation shell: bottom nav (Transactions / Reports / Budgets /
/// Settings) with a center-docked FAB for "add transaction", matching the
/// reference app's bottom-nav-with-raised-pencil-FAB layout. Accounts
/// management lives under Settings rather than as its own tab.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // Only the active tab's screen (and its providers/DB queries) gets built
  // on first frame; the rest are built the first time they're visited, then
  // kept alive in the IndexedStack like before. Cuts cold-start work since
  // Settings/Reports/Budgets no longer all build before the first frame.
  final _visited = <int>{0};

  static const _tabBuilders = <Widget Function()>[
    TransactionsTab.new,
    ReportsScreen.new,
    ManageBudgetsScreen.new,
    SettingsScreen.new,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _tabBuilders.length; i++)
            _visited.contains(i) ? _tabBuilders[i]() : const SizedBox.shrink(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMenu(context),
        child: const Icon(Icons.edit),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        child: Row(
          // Two equal-width halves split exactly at screen-center, which is
          // also where floatingActionButtonLocation.centerDocked always
          // places the FAB/notch — so they line up regardless of how many
          // buttons end up in each half (a fixed-width spacer here doesn't
          // reliably match the notch's actual position).
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavButton(
                    icon: Icons.list_alt_outlined,
                    selectedIcon: Icons.list_alt,
                    label: 'Transactions',
                    selected: _index == 0,
                    onTap: () => _selectTab(0),
                  ),
                  _NavButton(
                    icon: Icons.pie_chart_outline,
                    selectedIcon: Icons.pie_chart,
                    label: 'Reports',
                    selected: _index == 1,
                    onTap: () => _selectTab(1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavButton(
                    icon: Icons.savings_outlined,
                    selectedIcon: Icons.savings,
                    label: 'Budgets',
                    selected: _index == 2,
                    onTap: () => _selectTab(2),
                  ),
                  _NavButton(
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    label: 'Settings',
                    selected: _index == 3,
                    onTap: () => _selectTab(3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectTab(int index) {
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  /// Matches the reference app: the center FAB opens a small menu (Tambah
  /// Transaksi / Transfer Saldo) rather than jumping straight to Add
  /// Transaction. Add Budget is an extra entry beyond the reference app.
  void _showAddMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Add Transaction'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddTransactionScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Transfer'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddTransferScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.savings_outlined),
              title: const Text('Add Budget'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BudgetFormScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Colors.grey;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        // Icon-only per repo owner feedback; Tooltip keeps the label
        // available on long-press/hover and for accessibility.
        child: Tooltip(
          message: label,
          child: Icon(selected ? selectedIcon : icon, color: color),
        ),
      ),
    );
  }
}
