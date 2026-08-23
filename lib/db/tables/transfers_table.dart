import 'package:drift/drift.dart';

import 'accounts_table.dart';

/// Own entity rather than two linked Transactions rows: keeps
/// Transactions.categoryId always meaningful (transfers aren't categorized)
/// and keeps cross-currency leg amounts first-class columns instead of
/// overloading a single `amount` with two different currencies' meaning.
class Transfers extends Table {
  IntColumn get id => integer().autoIncrement()();

  @ReferenceName('transfersOut')
  IntColumn get fromAccountId => integer().references(Accounts, #id)();
  @ReferenceName('transfersIn')
  IntColumn get toAccountId => integer().references(Accounts, #id)();

  /// Minor units in fromAccount's currency.
  IntColumn get fromAmount => integer()();

  /// Minor units in toAccount's currency. UI auto-fills this equal to
  /// fromAmount (converted 1:1) when both accounts share a currency, but it
  /// stays independently editable (e.g. to record a transfer fee), and must
  /// be entered manually when currencies differ. The effective rate is
  /// derived on read (toAmount/toScale ÷ fromAmount/fromScale), never stored.
  IntColumn get toAmount => integer()();

  TextColumn get note => text().nullable()();

  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
}
