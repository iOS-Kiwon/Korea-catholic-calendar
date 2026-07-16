import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/category_providers.dart';
import '../model/category_palette.dart';
import '../model/event_category.dart';

/// Opens the category management screen.
Future<void> openCategoryManager(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const CategoryManagerPage()),
  );
}

/// Add/edit/delete/reorder the user's event categories.
class CategoryManagerPage extends ConsumerWidget {
  const CategoryManagerPage({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    EventCategory category,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('카테고리 삭제'),
        content: Text(
          "'${category.name}' 카테고리를 삭제할까요?\n"
          '이미 등록된 일정은 그대로 유지됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(categoriesProvider.notifier).delete(category.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('카테고리 관리')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCategoryEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('카테고리 추가'),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오지 못했습니다.\n$e')),
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  '카테고리가 없습니다.\n오른쪽 아래 버튼으로 추가하세요.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: categories.length,
            onReorderItem: (oldIndex, newIndex) => ref
                .read(categoriesProvider.notifier)
                .reorder(oldIndex, newIndex),
            itemBuilder: (context, i) {
              final c = categories[i];
              return ListTile(
                key: ValueKey(c.id),
                leading: _Swatch(color: Color(c.color)),
                title: Text(c.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: '삭제',
                      onPressed: () => _confirmDelete(context, ref, c),
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 4, right: 8),
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                  ],
                ),
                onTap: () => showCategoryEditor(context, existing: c),
              );
            },
          );
        },
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, this.size = 26, this.selected = false});

  final Color color;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: selected
            ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
            : null,
      ),
      child: selected
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : null,
    );
  }
}

/// Opens the add/edit category sheet. Returns the created/edited category id,
/// or null if cancelled.
Future<String?> showCategoryEditor(
  BuildContext context, {
  EventCategory? existing,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CategoryEditorSheet(existing: existing),
  );
}

class _CategoryEditorSheet extends ConsumerStatefulWidget {
  const _CategoryEditorSheet({this.existing});

  final EventCategory? existing;

  @override
  ConsumerState<_CategoryEditorSheet> createState() =>
      _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends ConsumerState<_CategoryEditorSheet> {
  late final TextEditingController _name;
  late int _color;
  bool _nameError = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _color = widget.existing?.color ?? kCategoryColors.first;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = true);
      return;
    }
    final notifier = ref.read(categoriesProvider.notifier);
    String id;
    if (_isEditing) {
      id = widget.existing!.id;
      await notifier.edit(id, name: name, color: _color);
    } else {
      final created = await notifier.add(name, _color);
      id = created.id;
    }
    if (mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEditing ? '카테고리 수정' : '새 카테고리',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: '이름',
              hintText: '예: 본당 행사, 성당 청소',
              errorText: _nameError ? '이름을 입력하세요' : null,
              prefixIcon: const Icon(Icons.label_outline),
            ),
            onChanged: (_) {
              if (_nameError) setState(() => _nameError = false);
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('색상', style: theme.textTheme.titleSmall),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in kCategoryColors)
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: _Swatch(color: Color(c), size: 34, selected: c == _color),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(_isEditing ? '저장' : '추가'),
            ),
          ),
        ],
      ),
    );
  }
}
