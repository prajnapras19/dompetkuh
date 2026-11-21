import '../db/database.dart';

/// One category's share of a period's income or expense — feeds the
/// Reports screen's donut chart and breakdown list. [category] is null for
/// the synthetic "Transfer" entry: transfer legs count as income/expense
/// (see CLAUDE.md) but have no category of their own.
class CategoryBreakdownEntry {
  final Category? category;
  final int totalAmount;
  final int transactionCount;

  const CategoryBreakdownEntry({
    required this.category,
    required this.totalAmount,
    required this.transactionCount,
  });

  bool get isTransfer => category == null;
  String get name => category?.name ?? 'Transfer';
  String? get iconKey => category?.icon ?? 'transfer';
}
