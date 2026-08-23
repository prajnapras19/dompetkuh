import '../db/database.dart';

/// A transaction joined with its category, for list/log display.
class TransactionEntry {
  final Transaction transaction;
  final Category category;

  const TransactionEntry({required this.transaction, required this.category});
}
