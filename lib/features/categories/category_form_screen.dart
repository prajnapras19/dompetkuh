import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/database.dart';
import '../../providers/category_providers.dart';
import '../../widgets/icon_picker_field.dart';

/// Create or edit a category. [category] null = create; [initialType]
/// seeds the in/out type for a new category (ignored when editing).
class CategoryFormScreen extends ConsumerStatefulWidget {
  final Category? category;
  final String initialType;

  const CategoryFormScreen({
    super.key,
    this.category,
    this.initialType = CategoryType.out,
  });

  @override
  ConsumerState<CategoryFormScreen> createState() =>
      _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _type;
  String? _iconKey;
  int? _colorValue;
  bool _saving = false;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    _nameController = TextEditingController(text: c?.name ?? '');
    _type = c?.type ?? widget.initialType;
    _iconKey = c?.icon ?? 'other';
    _colorValue = c?.color ?? 0xFF757575;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Category' : 'Add Category'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            Center(
              child: IconPickerField(
                iconKey: _iconKey,
                colorValue: _colorValue,
                onChanged: (entry) => setState(() {
                  _iconKey = entry.key;
                  _colorValue = entry.defaultColor;
                }),
              ),
            ),
            const SizedBox(height: 24),
            const _Caption('NAME'),
            TextFormField(
              controller: _nameController,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            const _Caption('TYPE'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: CategoryType.in_, label: Text('Income')),
                ButtonSegment(value: CategoryType.out, label: Text('Expense')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(categoryRepositoryProvider);

    int id;
    if (_isEditing) {
      id = widget.category!.id;
      await repo.update(
        widget.category!.copyWith(
          name: _nameController.text.trim(),
          type: _type,
          icon: Value(_iconKey),
          color: Value(_colorValue),
        ),
      );
    } else {
      id = await repo.create(
        CategoriesCompanion.insert(
          name: _nameController.text.trim(),
          type: _type,
          icon: Value(_iconKey),
          color: Value(_colorValue),
        ),
      );
    }

    // Returns the saved category's id so a picker screen that pushed this
    // form for a quick-add can select it immediately.
    if (mounted) Navigator.of(context).pop(id);
  }
}

class _Caption extends StatelessWidget {
  final String text;
  const _Caption(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
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
