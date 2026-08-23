import '../db/database.dart';

/// One category's share of a period's income or expense — feeds the
/// Reports screen's donut chart and breakdown list.
class CategoryBreakdownEntry {
  final Category category;
  final int totalAmount;
  final int transactionCount;

  const CategoryBreakdownEntry({
    required this.category,
    required this.totalAmount,
    required this.transactionCount,
  });
}
