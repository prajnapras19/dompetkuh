import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import 'database_provider.dart';

/// Active categories of a given type ('in' | 'out'), for pickers.
final categoriesByTypeProvider = StreamProvider.family<List<Category>, String>(
  (ref, type) {
    final db = ref.watch(databaseProvider);
    return (db.select(db.categories)
          ..where((c) => c.type.equals(type) & c.archivedAt.isNull())
          ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
        .watch();
  },
);

/// All categories of a type including archived, for the Manage Categories screen.
final allCategoriesByTypeProvider =
    StreamProvider.family<List<Category>, String>((ref, type) {
      final db = ref.watch(databaseProvider);
      return (db.select(db.categories)
            ..where((c) => c.type.equals(type))
            ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
          .watch();
    });

final categoryByIdProvider = StreamProvider.family<Category?, int>((
  ref,
  id,
) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.categories,
  )..where((c) => c.id.equals(id))).watchSingleOrNull();
});

class CategoryRepository {
  CategoryRepository(this._db);
  final AppDatabase _db;

  Future<int> create(CategoriesCompanion entry) {
    return _db.into(_db.categories).insert(entry);
  }

  Future<bool> update(Category category) {
    return _db.update(_db.categories).replace(category);
  }

  Future<bool> isInUse(int categoryId) async {
    final count = await (_db.selectOnly(_db.transactions)
          ..addColumns([_db.transactions.id.count()])
          ..where(_db.transactions.categoryId.equals(categoryId)))
        .map((row) => row.read(_db.transactions.id.count()) ?? 0)
        .getSingle();
    return count > 0;
  }

  Future<void> archive(int categoryId) {
    return (_db.update(_db.categories)..where((c) => c.id.equals(categoryId)))
        .write(CategoriesCompanion(archivedAt: Value(DateTime.now())));
  }

  Future<void> unarchive(int categoryId) {
    return (_db.update(_db.categories)..where((c) => c.id.equals(categoryId)))
        .write(const CategoriesCompanion(archivedAt: Value(null)));
  }

  Future<void> delete(int categoryId) {
    return (_db.delete(
      _db.categories,
    )..where((c) => c.id.equals(categoryId))).go();
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(databaseProvider));
});
