import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/category_providers.dart';
import '../application/event_providers.dart';
import '../model/calendar_event.dart';
import '../model/event_category.dart';
import 'category_manager_page.dart';

const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

String _two(int n) => n.toString().padLeft(2, '0');

String _dateLabel(DateTime d) =>
    '${d.year}년 ${d.month}월 ${d.day}일 (${_weekdays[d.weekday % 7]})';

/// Opens the add/edit event sheet. Pass [existing] to edit; otherwise a new
/// event is created on [date].
Future<void> showEventEditor(
  BuildContext context, {
  required DateTime date,
  CalendarEvent? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EventEditorSheet(date: date, existing: existing),
  );
}

class _EventEditorSheet extends ConsumerStatefulWidget {
  const _EventEditorSheet({required this.date, this.existing});

  final DateTime date;
  final CalendarEvent? existing;

  @override
  ConsumerState<_EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends ConsumerState<_EventEditorSheet>
    with WidgetsBindingObserver {
  late final TextEditingController _memo;
  late DateTime _date;
  TimeOfDay? _time; // null = 종일(all-day)
  late bool _notify;
  String? _selectedCategoryId;
  bool _categoryError = false;
  bool? _systemNotificationsEnabled;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final e = widget.existing;
    _memo = TextEditingController(text: e?.memo ?? '');
    _date = e != null ? parseEventDate(e.date) : _dateOnly(widget.date);
    _time = _parseTime(e?.time);
    _notify = e?.notify ?? true;
    _selectedCategoryId = e?.categoryId;
    _refreshNotificationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _memo.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotificationPermission();
    }
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static TimeOfDay? _parseTime(String? hhmm) {
    if (hhmm == null) return null;
    final p = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(p[0]) ?? 9,
      minute: p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0,
    );
  }

  /// Resolves the currently selected category from the live list, falling back
  /// to the event's own snapshot when editing (so a category selection always
  /// renders even for legacy/edge data).
  EventCategory? _resolveSelected(List<EventCategory> live) {
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      return null;
    }
    for (final c in live) {
      if (c.id == _selectedCategoryId) return c;
    }
    final e = widget.existing;
    if (e != null && e.categoryId == _selectedCategoryId) {
      return EventCategory(
        id: e.categoryId,
        name: e.categoryName,
        color: e.categoryColor,
      );
    }
    return null;
  }

  Future<void> _openCategoryPicker() async {
    final id = await pickCategory(context);
    if (id != null) {
      setState(() {
        _selectedCategoryId = id;
        _categoryError = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = _dateOnly(picked));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _refreshNotificationPermission() async {
    final enabled = await ref
        .read(notificationServiceProvider)
        .areNotificationsEnabled();
    if (!mounted) return;
    setState(() {
      _systemNotificationsEnabled = enabled;
      if (!enabled) _notify = false;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    if (!value) {
      setState(() => _notify = false);
      return;
    }

    final service = ref.read(notificationServiceProvider);
    final enabled = await service.areNotificationsEnabled();
    if (!mounted) return;
    if (!enabled) {
      setState(() {
        _systemNotificationsEnabled = false;
        _notify = false;
      });
      await service.openNotificationSettings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시스템 알림이 꺼져 있어 앱 알림 설정으로 이동합니다.')),
      );
      return;
    }

    setState(() {
      _systemNotificationsEnabled = true;
      _notify = true;
    });
  }

  String _reminderHelpText() {
    final dayOfTime = _time == null ? '오전 9:00' : _time!.format(context);
    return '알림은 전날 오후 9:00, 당일 $dayOfTime에 보냅니다. 이미 지난 시간의 알림은 예약하지 않습니다.';
  }

  Future<void> _save(List<EventCategory> categories) async {
    final category = _resolveSelected(categories);
    if (category == null) {
      setState(() => _categoryError = true);
      return;
    }

    final memo = _memo.text.trim();
    final time = _time == null
        ? null
        : '${_two(_time!.hour)}:${_two(_time!.minute)}';
    final event = CalendarEvent(
      id:
          widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      date: eventDateKey(_date),
      categoryId: category.id,
      categoryName: category.name,
      categoryColor: category.color,
      memo: memo.isEmpty ? null : memo,
      time: time,
      notify: _systemNotificationsEnabled == false ? false : _notify,
    );

    final store = ref.read(eventStoreProvider.notifier);
    if (_isEditing) {
      await store.updateEvent(event);
    } else {
      await store.add(event);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    await ref.read(eventStoreProvider.notifier).delete(existing);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final allDay = _time == null;
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final selected = _resolveSelected(categories);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  _isEditing ? '일정 수정' : '새 일정',
                  style: theme.textTheme.titleLarge,
                ),
                const Spacer(),
                if (_isEditing)
                  IconButton(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '삭제',
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // 날짜 (필수)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(_dateLabel(_date)),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: _pickDate,
            ),

            // 카테고리 (필수) - 제목을 직접 입력하지 않고, 탭 → 카테고리 화면에서 선택.
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: selected != null
                  ? CircleAvatar(
                      backgroundColor: Color(selected.color),
                      radius: 13,
                    )
                  : const Icon(Icons.label_outline),
              title: Text(selected?.name ?? '카테고리를 선택하세요'),
              subtitle: _categoryError
                  ? Text(
                      '카테고리를 선택하세요',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    )
                  : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: _openCategoryPicker,
            ),
            const SizedBox(height: 4),

            // 메모 (선택)
            TextField(
              controller: _memo,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                hintText: '부가 설명',
                prefixIcon: Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 4),

            // 종일 / 시간
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.schedule),
              title: const Text('종일'),
              value: allDay,
              onChanged: (v) => setState(
                () => _time = v ? null : const TimeOfDay(hour: 9, minute: 0),
              ),
            ),
            if (!allDay)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40),
                title: const Text('시간'),
                trailing: Text(
                  _time!.format(context),
                  style: theme.textTheme.titleMedium,
                ),
                onTap: _pickTime,
              ),

            // 알림
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('알림'),
              subtitle: Text(
                _systemNotificationsEnabled == false
                    ? '${_reminderHelpText()}\n시스템 알림이 꺼져 있어 알림을 보낼 수 없습니다.'
                    : _reminderHelpText(),
              ),
              value: _systemNotificationsEnabled == false ? false : _notify,
              onChanged: _toggleNotifications,
            ),
            const SizedBox(height: 12),

            FilledButton(
              onPressed: () => _save(categories),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(_isEditing ? '저장' : '추가'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
