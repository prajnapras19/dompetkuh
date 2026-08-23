import '../db/database.dart';
import 'ledger_entry.dart';

/// A LedgerEntry (transaction or one transfer leg) attributed to the
/// account+currency it belongs to — feeds the home Transactions tab, which
/// spans every account rather than one.
class GlobalLedgerEntry {
  final LedgerEntry entry;
  final Account account;
  final Currency currency;

  const GlobalLedgerEntry({
    required this.entry,
    required this.account,
    required this.currency,
  });
}
