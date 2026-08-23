import '../db/database.dart';

/// An account joined with its currency and a live-computed balance —
/// everything the Accounts Overview / Account Detail header needs in one
/// row, so the list screen doesn't open one balance stream per account.
class AccountSummary {
  final Account account;
  final Currency currency;
  final int balance;

  const AccountSummary({
    required this.account,
    required this.currency,
    required this.balance,
  });
}
