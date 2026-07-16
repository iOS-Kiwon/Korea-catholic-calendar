import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/event_providers.dart';
import '../model/calendar_event.dart';

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

class _EventEditorSheetState extends ConsumerState<_EventEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _memo;
  late DateTime _date;
  TimeOfDay? _time; // null = 종일(all-day)
  late bool _notify;
  bool _titleError = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _memo = TextEditingController(text: e?.memo ?? '');
    _date = e != null ? parseEventDate(e.date) : _dateOnly(widget.date);
    _time = _parseTime(e?.time);
    _notify = e?.notify ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _memo.dispose();
    super.dispose();
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

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = true);
      return;
    }
    final memo = _memo.text.trim();
    final time = _time == null ? null : '${_two(_time!.hour)}:${_two(_time!.minute)}';
    final event = CalendarEvent(
      id: widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      date: eventDateKey(_date),
      title: title,
      memo: memo.isEmpty ? null : memo,
      time: time,
      notify: _notify,
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

            // 제목 (필수)
            TextField(
              controller: _title,
              autofocus: !_isEditing,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: '제목',
                hintText: '일정 제목',
                errorText: _titleError ? '제목을 입력하세요' : null,
                prefixIcon: const Icon(Icons.title),
              ),
              onChanged: (_) {
                if (_titleError) setState(() => _titleError = false);
              },
            ),
            const SizedBox(height: 12),

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
              subtitle: const Text('전날 저녁·당일에 알림'),
              value: _notify,
              onChanged: (v) => setState(() => _notify = v),
            ),
            const SizedBox(height: 12),

            FilledButton(
              onPressed: _save,
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
