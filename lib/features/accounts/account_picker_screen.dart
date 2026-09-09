import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/account_providers.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/money_text.dart';
import 'account_form_screen.dart';

/// Sentinel returned for the "All accounts" entry (only shown when
/// [AccountPickerScreen.showAllOption] is true, e.g. the Transactions tab's
/// filter sheet) — a distinct, explicit "clear the filter" choice, as
/// opposed to backing out with no selection (a real `null`). Account ids
/// are Drift autoincrement primary keys, so 0 is never a real one.
const allAccountsId = 0;

/// Full-page account picker matching the reference app's Pilih Rekening
/// screen — alphabetical by name with each account's live balance shown
/// underneath, a different order than the drag-reorderable Manage Accounts
/// screen. The "+" quick-adds an account without leaving the transaction
/// form. [excludeId] hides one account (Transfer's "to account" picker uses
/// this so you can't transfer to the same account you're sending from).
class AccountPickerScreen extends ConsumerWidget {
  final int? excludeId;
  final bool showAllOption;

  const AccountPickerScreen({
    super.key,
    this.excludeId,
    this.showAllOption = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountSummariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Account'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _quickAdd(context),
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (accounts) {
          final sorted =
              accounts.where((a) => a.account.id != excludeId).toList()
                ..sort(
                  (a, b) => a.account.name.toLowerCase().compareTo(
                    b.account.name.toLowerCase(),
                  ),
                );
          if (sorted.isEmpty && !showAllOption) {
            return const Center(
              child: Text(
                'No accounts yet — tap + to add one.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          return ListView(
            children: [
              if (showAllOption)
                ListTile(
                  leading: const Icon(Icons.clear_all, color: Colors.grey),
                  title: const Text('All accounts'),
                  onTap: () => Navigator.of(context).pop(allAccountsId),
                ),
              for (final account in sorted)
                ListTile(
                  leading: IconTile(
                    iconKey: account.account.icon,
                    colorValue: account.account.color,
                  ),
                  title: Text(account.account.name),
                  subtitle: MoneyText(
                    minorUnits: account.balance,
                    currency: account.currency,
                  ),
                  onTap: () => Navigator.of(context).pop(account.account.id),
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
    ).push<int>(MaterialPageRoute(builder: (_) => const AccountFormScreen()));
    if (newId != null && context.mounted) Navigator.of(context).pop(newId);
  }
}
