import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ads/ads.dart';
import '../application/category_providers.dart';
import '../model/category_palette.dart';
import '../model/event_category.dart';

/// Opens the "카테고리" screen and returns the id of the category the user
/// picked, or null if they backed out without picking.
Future<String?> pickCategory(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute<String>(builder: (_) => const CategoryPickerPage()),
  );
}

/// The "카테고리" screen. Two modes:
/// - **선택**(default): tap a category → returns it to the previous screen.
///   App bar shows a ⚙ button (→ edit mode) and a FAB to add.
/// - **편집**: each row gets rename/delete/move affordances; the ⚙ becomes a
///   저장 button. Edits are held locally and committed on 저장.
class CategoryPickerPage extends ConsumerStatefulWidget {
  const CategoryPickerPage({super.key});

  @override
  ConsumerState<CategoryPickerPage> createState() => _CategoryPickerPageState();
}

class _CategoryPickerPageState extends ConsumerState<CategoryPickerPage> {
  bool _editing = false;
  List<EventCategory> _draft = const [];

  void _enterEdit(List<EventCategory> current) {
    setState(() {
      _editing = true;
      _draft = [...current];
    });
  }

  Future<void> _save() async {
    final draft = [..._draft];
    await ref.read(categoriesProvider.notifier).replaceAll(draft);
    if (mounted) {
      setState(() {
        _editing = false;
        _draft = const [];
      });
    }
  }

  Future<void> _add() async {
    final result = await showCategoryFormSheet(context);
    if (result != null) {
      await ref.read(categoriesProvider.notifier).add(result.name, result.color);
    }
  }

  Future<void> _renameInDraft(EventCategory c) async {
    final result = await showCategoryFormSheet(context, existing: c);
    if (result == null) return;
    setState(() {
      final i = _draft.indexWhere((x) => x.id == c.id);
      if (i != -1) {
        _draft[i] = c.copyWith(name: result.name, color: result.color);
      }
    });
  }

  void _deleteInDraft(EventCategory c, {required bool inUse}) {
    if (inUse) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사용 중인 카테고리는 삭제할 수 없습니다. 먼저 해당 일정을 정리하세요.'),
        ),
      );
      return;
    }
    setState(() => _draft.removeWhere((x) => x.id == c.id));
  }

  void _reorderInDraft(int oldIndex, int newIndex) {
    setState(() {
      final item = _draft.removeAt(oldIndex);
      _draft.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final inUseIds = ref.watch(inUseCategoryIdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('카테고리'),
        actions: [
          if (categoriesAsync.hasValue)
            _editing
                ? TextButton(onPressed: _save, child: const Text('저장'))
                : IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: '편집',
                    onPressed: () => _enterEdit(categoriesAsync.value!),
                  ),
        ],
      ),
      floatingActionButton: _editing
          ? null
          : FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('카테고리 추가'),
            ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오지 못했습니다.\n$e')),
        data: (categories) {
          final list = _editing ? _draft : categories;
          if (list.isEmpty) {
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
          return _editing
              ? _buildEditList(list, inUseIds)
              : _buildSelectList(list);
        },
      ),
    );
  }

  Widget _buildSelectList(List<EventCategory> categories) {
    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final c = categories[i];
        return ListTile(
          leading: _Swatch(color: Color(c.color)),
          title: Text(c.name),
          onTap: () => Navigator.of(context).pop(c.id),
        );
      },
    );
  }

  Widget _buildEditList(List<EventCategory> categories, Set<String> inUseIds) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: categories.length,
      onReorderItem: _reorderInDraft,
      itemBuilder: (context, i) {
        final c = categories[i];
        final inUse = inUseIds.contains(c.id);
        return ListTile(
          key: ValueKey(c.id),
          leading: _Swatch(color: Color(c.color)),
          title: Text(c.name),
          subtitle: inUse ? const Text('사용 중') : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: '이름/색 수정',
                onPressed: () => _renameInDraft(c),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '삭제',
                color: inUse ? Theme.of(context).disabledColor : null,
                onPressed: () => _deleteInDraft(c, inUse: inUse),
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
        );
      },
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
            ? Border.all(
                color: Theme.of(context).colorScheme.onSurface,
                width: 3,
              )
            : null,
      ),
      child: selected
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : null,
    );
  }
}

/// Opens the add/edit category form as a full-screen page (no persistence).
/// Returns the entered (name, color) or null if cancelled. A full page (rather
/// than a bottom sheet) avoids keyboard jank and matches the event editor.
Future<({String name, int color})?> showCategoryFormSheet(
  BuildContext context, {
  EventCategory? existing,
}) {
  return Navigator.of(context).push<({String name, int color})>(
    MaterialPageRoute<({String name, int color})>(
      builder: (_) => _CategoryFormSheet(existing: existing),
    ),
  );
}

class _CategoryFormSheet extends StatefulWidget {
  const _CategoryFormSheet({this.existing});

  final EventCategory? existing;

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
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

  void _submit() {
    final name = normalizeCategoryName(_name.text);
    if (name.isEmpty) {
      setState(() => _nameError = true);
      return;
    }
    Navigator.of(context).pop((name: name, color: _color));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '카테고리 수정' : '새 카테고리')),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: kMaxCategoryNameLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              // 완료(return) 키는 제출이 아니라 키보드만 닫는다.
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                labelText: '이름',
                hintText: '예: 본당 행사, 전례',
                errorText: _nameError ? '이름을 입력하세요' : null,
                prefixIcon: const Icon(Icons.label_outline),
              ),
              onChanged: (_) {
                if (_nameError) setState(() => _nameError = false);
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('색상', style: theme.textTheme.titleSmall),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final c in kCategoryColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: _Swatch(
                      color: Color(c),
                      size: 34,
                      selected: c == _color,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      // 추가/저장 버튼은 화면 하단에 고정(일정 추가 버튼과 동일).
      bottomNavigationBar: SafeArea(
        top: false,
        bottom: !adsEnabled,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(_isEditing ? '저장' : '추가'),
            ),
          ),
        ),
      ),
    );
  }
}
