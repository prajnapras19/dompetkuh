import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/database.dart';
import '../../providers/category_providers.dart';
import '../../widgets/icon_tile.dart';
import 'category_form_screen.dart';

/// Sentinel returned for the "All categories" entry (only shown when
/// [CategoryPickerScreen.showAllOption] is true, e.g. the Transactions tab's
/// filter sheet) — a distinct, explicit "clear the filter" choice, as
/// opposed to backing out with no selection (a real `null`). Category ids
/// are Drift autoincrement primary keys, so 0 is never a real one.
const allCategoriesId = 0;

/// Full-page category picker matching the reference app's Pilih
/// Kategori/Pengeluaran screen — alphabetical by name, which is a
/// *different* order than the drag-reorderable Manage Categories screen
/// (that one preserves the user's own arrangement; this one is a quick
/// lookup list). The "+" quick-adds a category of the same type without
/// leaving the transaction form.
///
/// [type] null means "both" (Income and Expense sections together, for the
/// Transactions tab's filter sheet, which isn't scoped to one type) — the
/// "+" quick-add is hidden in that case since there's no single type to
/// default a new category to.
class CategoryPickerScreen extends ConsumerWidget {
  final String? type;
  final bool showAllOption;

  const CategoryPickerScreen({super.key, required this.type, this.showAllOption = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          type == null
              ? 'Select Category'
              : 'Select ${type == CategoryType.in_ ? 'Income' : 'Expense'} Category',
        ),
        actions: [
          if (type != null)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _quickAdd(context, type!),
            ),
        ],
      ),
      body: type != null
          ? _CategorySection(type: type!, onPicked: (id) => Navigator.of(context).pop(id))
          : ListView(
              children: [
                if (showAllOption)
                  ListTile(
                    leading: const Icon(Icons.clear_all, color: Colors.grey),
                    title: const Text('All categories'),
                    onTap: () => Navigator.of(context).pop(allCategoriesId),
                  ),
                _SectionHeader('INCOME'),
                _CategorySection(
                  type: CategoryType.in_,
                  onPicked: (id) => Navigator.of(context).pop(id),
                  shrinkWrap: true,
                ),
                _SectionHeader('EXPENSE'),
                _CategorySection(
                  type: CategoryType.out,
                  onPicked: (id) => Navigator.of(context).pop(id),
                  shrinkWrap: true,
                ),
              ],
            ),
    );
  }

  Future<void> _quickAdd(BuildContext context, String type) async {
    final newId = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => CategoryFormScreen(initialType: type)),
    );
    if (newId != null && context.mounted) Navigator.of(context).pop(newId);
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _CategorySection extends ConsumerWidget {
  final String type;
  final ValueChanged<int> onPicked;
  final bool shrinkWrap;

  const _CategorySection({
    required this.type,
    required this.onPicked,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesByTypeProvider(type));

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (categories) {
        final sorted = [...categories]..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        if (sorted.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No categories yet — tap + to add one.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final category = sorted[index];
            return ListTile(
              leading: IconTile(
                iconKey: category.icon,
                colorValue: category.color,
              ),
              title: Text(category.name),
              onTap: () => onPicked(category.id),
            );
          },
        );
      },
    );
  }
}
