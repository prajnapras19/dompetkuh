import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/currency_providers.dart';
import 'currency_form_screen.dart';

class ManageCurrenciesScreen extends ConsumerWidget {
  const ManageCurrenciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currenciesAsync = ref.watch(allCurrenciesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Currencies')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CurrencyFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: currenciesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (currencies) {
          return ListView.builder(
            itemCount: currencies.length,
            itemBuilder: (context, index) {
              final currency = currencies[index];
              final archived = currency.archivedAt != null;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: archived ? Colors.grey : Colors.blueGrey,
                  child: Text(
                    currency.symbol.characters.first,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  '${currency.code} — ${currency.name}',
                  style: archived
                      ? const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                        )
                      : null,
                ),
                subtitle: Text(
                  currency.subunitName != null
                      ? '${currency.decimalPlaces} dp · ${currency.subunitName}'
                      : '${currency.decimalPlaces} dp',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) => _handleAction(
                    context,
                    ref,
                    currency.id,
                    archived,
                    action,
                  ),
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
                    MaterialPageRoute(
                      builder: (_) => CurrencyFormScreen(currency: currency),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    int currencyId,
    bool archived,
    String action,
  ) async {
    final repo = ref.read(currencyRepositoryProvider);
    switch (action) {
      case 'edit':
        final currency = await ref.read(
          currencyByIdProvider(currencyId).future,
        );
        if (currency != null && context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CurrencyFormScreen(currency: currency),
            ),
          );
        }
      case 'archive':
        await repo.archive(currencyId);
      case 'unarchive':
        await repo.unarchive(currencyId);
      case 'delete':
        final inUse = await repo.isInUse(currencyId);
        if (inUse) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'This currency is used by an account — archive it instead.',
                ),
              ),
            );
          }
          return;
        }
        await repo.delete(currencyId);
    }
  }
}
