import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/database.dart';
import '../../providers/category_providers.dart';
import '../../widgets/icon_tile.dart';
import 'category_form_screen.dart';

/// Full-page category picker matching the reference app's Pilih
/// Kategori/Pengeluaran screen — alphabetical by name, which is a
/// *different* order than the drag-reorderable Manage Categories screen
/// (that one preserves the user's own arrangement; this one is a quick
/// lookup list). The "+" quick-adds a category of the same type without
/// leaving the transaction form.
class CategoryPickerScreen extends ConsumerWidget {
  final String type;

  const CategoryPickerScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesByTypeProvider(type));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Select ${type == CategoryType.in_ ? 'Income' : 'Expense'} Category',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _quickAdd(context),
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (categories) {
          final sorted = [...categories]..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          if (sorted.isEmpty) {
            return const Center(
              child: Text(
                'No categories yet — tap + to add one.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final category = sorted[index];
              return ListTile(
                leading: IconTile(
                  iconKey: category.icon,
                  colorValue: category.color,
                ),
                title: Text(category.name),
                onTap: () => Navigator.of(context).pop(category.id),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _quickAdd(BuildContext context) async {
    final newId = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => CategoryFormScreen(initialType: type),
      ),
    );
    if (newId != null && context.mounted) Navigator.of(context).pop(newId);
  }
}
