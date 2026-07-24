import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ads/ads.dart';
import '../../calendar/application/calendar_providers.dart';
import '../application/category_providers.dart';
import '../application/event_providers.dart';
import '../model/calendar_event.dart';
import '../model/event_category.dart';
import '../model/recurrence.dart';
import 'backup_notice.dart';
import 'category_manager_page.dart';

const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

String _two(int n) => n.toString().padLeft(2, '0');

String _dateLabel(DateTime d) =>
    '${d.year}년 ${d.month}월 ${d.day}일 (${_weekdays[d.weekday % 7]})';

/// Opens the add/edit event screen. Pass [existing] to edit; otherwise a new
/// event is created on [date].
Future<void> showEventEditor(
  BuildContext context, {
  required DateTime date,
  CalendarEvent? existing,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => _EventEditorPage(date: date, existing: existing),
    ),
  );
}

class _EventEditorPage extends ConsumerStatefulWidget {
  const _EventEditorPage({required this.date, this.existing});

  final DateTime date;
  final CalendarEvent? existing;

  @override
  ConsumerState<_EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends ConsumerState<_EventEditorPage>
    with WidgetsBindingObserver {
  late final TextEditingController _memo;
  late DateTime _date;
  TimeOfDay? _time; // null = 종일(all-day)
  late bool _notify;
  String? _selectedCategoryId;
  bool _categoryError = false;
  bool? _systemNotificationsEnabled;
  bool _enableNotifyWhenPermissionReturns = false;
  RecurrenceType _recurrence = RecurrenceType.none;
  String? _feastId;

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
    _recurrence = e?.recurrence ?? RecurrenceType.none;
    _feastId = e?.feastId;
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
      if (enabled && _enableNotifyWhenPermissionReturns) {
        _notify = true;
        _enableNotifyWhenPermissionReturns = false;
      } else if (!enabled) {
        _notify = false;
      }
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
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: const Text(
            '시스템 알림이 꺼져있어 알림을 보낼수 없습니다. 알림을 설정하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('아니오'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('예'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (openSettings == true) {
        _enableNotifyWhenPermissionReturns = true;
        await service.openNotificationSettings();
      }
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

  /// 현재 반복 설정을 사람이 읽는 요약으로. yearlyFeast는 그 날의 전례 축일명을 보여준다.
  String _recurrenceSummary() {
    switch (_recurrence) {
      case RecurrenceType.none:
        return '안 함';
      case RecurrenceType.daily:
        return '매일';
      case RecurrenceType.weekly:
        return '매주 ${_weekdays[_date.weekday % 7]}요일';
      case RecurrenceType.monthly:
        return '매월 ${_date.day}일';
      case RecurrenceType.yearlyDate:
        return '매년 ${_date.month}월 ${_date.day}일';
      case RecurrenceType.yearlyFeast:
        final cd = ref.read(calendarControllerProvider).value?.day(_date);
        final name = cd?.celebration.name;
        return (name != null && cd?.celebration.id == _feastId)
            ? '매년 $name'
            : '매년 전례 축일';
    }
  }

  /// 반복 선택 바텀시트. 매년(전례 축일)은 선택일이 주요 전례 축일일 때만 제공한다.
  Future<void> _pickRecurrence() async {
    final cd = ref.read(calendarControllerProvider).value?.day(_date);
    final feastId = cd?.celebration.id;
    final feastName = cd?.celebration.name;
    final feastAvailable =
        feastId != null && feastId != 'feria' && feastId != 'sunday';

    final options = <(RecurrenceType, String, String?)>[
      (RecurrenceType.none, '안 함', null),
      (RecurrenceType.daily, '매일', null),
      (RecurrenceType.weekly, '매주 ${_weekdays[_date.weekday % 7]}요일', null),
      (RecurrenceType.monthly, '매월 ${_date.day}일', null),
      (RecurrenceType.yearlyDate, '매년 ${_date.month}월 ${_date.day}일', null),
      if (feastAvailable)
        (RecurrenceType.yearlyFeast, '매년 $feastName (전례 축일)', feastId),
    ];

    final picked = await showModalBottomSheet<(RecurrenceType, String?)>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options)
              ListTile(
                title: Text(o.$2),
                trailing:
                    (_recurrence == o.$1 &&
                        (o.$1 != RecurrenceType.yearlyFeast ||
                            _feastId == o.$3))
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(ctx).pop((o.$1, o.$3)),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _recurrence = picked.$1;
        _feastId = picked.$2;
      });
    }
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
      recurrence: _recurrence,
      feastId: _recurrence == RecurrenceType.yearlyFeast ? _feastId : null,
    );

    final store = ref.read(eventStoreProvider.notifier);
    if (_isEditing) {
      await store.updateEvent(event);
    } else {
      await store.add(event);
      // 최초 1회: 일정 추가 완료 시점에 백업 안내(앱 실행/복원 시엔 뜨지 않음).
      if (mounted) await maybeShowBackupNotice(context, ref);
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
    final allDay = _time == null;
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final selected = _resolveSelected(categories);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '일정 수정' : '새 일정'),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: '삭제',
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          children: [
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

            // 반복 (선택)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.repeat),
              title: const Text('반복'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _recurrenceSummary(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: _pickRecurrence,
            ),
            const SizedBox(height: 4),

            // 메모 (선택) - 한 줄, 최대 100자, 완료(return) 키로 입력 종료.
            TextField(
              controller: _memo,
              maxLines: 1,
              maxLength: 100,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                hintText: '부가 설명',
                prefixIcon: Icon(Icons.sticky_note_2_outlined),
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
              subtitle: Text(_reminderHelpText()),
              value: _systemNotificationsEnabled == false ? false : _notify,
              onChanged: _toggleNotifications,
            ),
          ],
        ),
      ),
      // 추가/저장 버튼은 항상 화면 하단에 고정(광고 위). 키보드가 올라오면
      // 그 위로 자연스럽게 올라간다.
      bottomNavigationBar: SafeArea(
        top: false,
        bottom: !adsEnabled, // 광고가 켜지면 광고 배너가 하단 세이프영역을 처리.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _save(categories),
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
