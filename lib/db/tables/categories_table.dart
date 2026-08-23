import 'package:drift/drift.dart';

/// Category type: matches Transactions.type ('in' | 'out').
class CategoryType {
  static const in_ = 'in';
  static const out = 'out';
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  /// 'in' or 'out' — categories are scoped to one transaction type.
  TextColumn get type =>
      text().customConstraint("NOT NULL CHECK (type IN ('in', 'out'))")();

  /// Icon key used to look up a Flutter IconData in a fixed icon-set map
  /// (see widgets/icon_catalog.dart) — matches the reference app's icon
  /// picker grid.
  TextColumn get icon => text().nullable()();

  /// ARGB color for the category's icon tile background (e.g. 0xFFE53935),
  /// matching the reference app's colorful icon-tile style.
  IntColumn get color => integer().nullable()();

  BoolColumn get isPreset => boolean().withDefault(const Constant(false))();

  DateTimeColumn get archivedAt => dateTime().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
