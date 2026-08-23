import '../db/database.dart';

/// A transaction joined with its category, account, and that account's
/// currency — feeds the global (cross-account) Transactions tab.
class GlobalTransactionEntry {
  final Transaction transaction;
  final Category category;
  final Account account;
  final Currency currency;

  const GlobalTransactionEntry({
    required this.transaction,
    required this.category,
    required this.account,
    required this.currency,
  });
}
