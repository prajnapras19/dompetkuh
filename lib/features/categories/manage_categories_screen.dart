import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/database.dart';
import '../../providers/category_providers.dart';
import '../../widgets/icon_tile.dart';
import 'category_form_screen.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() =>
      _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentType =>
      _tabController.index == 0 ? CategoryType.in_ : CategoryType.out;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          tabs: const [Tab(text: 'INCOME'), Tab(text: 'EXPENSE')],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CategoryFormScreen(initialType: _currentType),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _CategoryList(type: CategoryType.in_),
          _CategoryList(type: CategoryType.out),
        ],
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  final String type;
  const _CategoryList({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(allCategoriesByTypeProvider(type));

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (categories) {
        return ListView.builder(
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final archived = category.archivedAt != null;
            return ListTile(
              leading: IconTile(
                iconKey: category.icon,
                colorValue: category.color,
              ),
              title: Text(
                category.name,
                style: archived
                    ? const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                      )
                    : null,
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (action) =>
                    _handleAction(context, ref, category.id, archived, action),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: archived ? 'unarchive' : 'archive',
                    child: Text(archived ? 'Unarchive' : 'Archive'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CategoryFormScreen(category: category),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    int categoryId,
    bool archived,
    String action,
  ) async {
    final repo = ref.read(categoryRepositoryProvider);
    switch (action) {
      case 'edit':
        final category = await ref.read(
          categoryByIdProvider(categoryId).future,
        );
        if (category != null && context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CategoryFormScreen(category: category),
            ),
          );
        }
      case 'archive':
        await repo.archive(categoryId);
      case 'unarchive':
        await repo.unarchive(categoryId);
      case 'delete':
        final inUse = await repo.isInUse(categoryId);
        if (inUse) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'This category is used by a transaction — archive it instead.',
                ),
              ),
            );
          }
          return;
        }
        await repo.delete(categoryId);
    }
  }
}
