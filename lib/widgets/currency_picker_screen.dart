import 'package:flutter/material.dart';

import '../db/database.dart';

/// Full-page currency picker (an app-specific field with no reference-app
/// equivalent — Dompetku doesn't support multiple currencies — styled to
/// match the Category/Account pickers) over a caller-supplied, already
/// filtered [currencies] list (each caller filters differently: Account
/// Form keeps a locked account's own currency even if archived, Budget
/// Form does the same for its own currency, etc.) — kept in the caller's
/// existing sortOrder rather than re-sorting alphabetically, since unlike
/// Categories/Accounts there's no on-device evidence of how the reference
/// app would order a currency list.
/// Sentinel returned for the "All currencies" entry (only shown when
/// [CurrencyPickerScreen.showAllOption] is true, e.g. the Transactions tab's
/// filter sheet) — a distinct, explicit "clear the filter" choice, as
/// opposed to backing out with no selection (a real `null`). Currency ids
/// are Drift autoincrement primary keys, so 0 is never a real one.
const allCurrenciesId = 0;

class CurrencyPickerScreen extends StatelessWidget {
  final List<Currency> currencies;
  final bool showAllOption;

  const CurrencyPickerScreen({
    super.key,
    required this.currencies,
    this.showAllOption = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Currency')),
      body: ListView(
        children: [
          if (showAllOption)
            ListTile(
              leading: const Icon(Icons.clear_all, color: Colors.grey),
              title: const Text('All currencies'),
              onTap: () => Navigator.of(context).pop(allCurrenciesId),
            ),
          for (final currency in currencies)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blueGrey.shade50,
                foregroundColor: Colors.blueGrey,
                child: Text(
                  currency.symbol,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(currency.code),
              subtitle: Text(currency.name),
              onTap: () => Navigator.of(context).pop(currency.id),
            ),
        ],
      ),
    );
  }
}
