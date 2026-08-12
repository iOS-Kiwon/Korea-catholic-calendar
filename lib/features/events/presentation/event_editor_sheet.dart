import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../ads/ads.dart';
import '../../calendar/application/calendar_providers.dart';
import '../application/category_providers.dart';
import '../application/event_providers.dart';
import '../model/calendar_event.dart';
import '../model/event_category.dart';
import '../model/recurrence.dart';
import '../model/reminder_lead.dart';
import '../notifications/notification_service.dart';
import '../../app_review/app_review_service.dart';
import '../../sharing/share_link.dart';
import 'backup_notice.dart';
import 'category_manager_page.dart';
import 'event_display.dart';
import 'reminder_editor.dart';

const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

String _two(int n) => n.toString().padLeft(2, '0');

String _dateButtonLabel(DateTime d) => '${d.year}. ${d.month}. ${d.day}.';

/// Opens the add/edit event screen. Pass [existing] to edit; otherwise a new
/// event is created on [date].
///
/// 신규 저장이 끝나면 앱스토어 리뷰 요청 조건을 확인한다(조건 미달이면 아무
/// 일도 일어나지 않는다). 호출부는 이를 신경 쓰지 않아도 된다.
Future<void> showEventEditor(
  BuildContext context, {
  required DateTime date,
  CalendarEvent? existing,
  SharedEventDraft? draft,
}) async {
  // pop 이후에도 유효해야 하므로 에디터가 아니라 호출부 context에서 얻는다.
  final container = ProviderScope.containerOf(context, listen: false);

  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) =>
          _EventEditorPage(date: date, existing: existing, draft: draft),
    ),
  );
  if (saved != true) return;

  // 페이지 전환이 완전히 끝난 뒤 띄운다.
  await Future<void>.delayed(const Duration(milliseconds: 400));
  await container.read(appReviewServiceProvider).maybeRequest();
}

class _EventEditorPage extends ConsumerStatefulWidget {
  const _EventEditorPage({required this.date, this.existing, this.draft});

  final DateTime date;
  final CalendarEvent? existing;
  final SharedEventDraft? draft;

  @override
  ConsumerState<_EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends ConsumerState<_EventEditorPage>
    with WidgetsBindingObserver {
  late final TextEditingController _memo;
  late DateTime _date;
  late DateTime _endDate;
  TimeOfDay? _time; // null = 종일(all-day)
  TimeOfDay? _endTime;
  late bool _notify;
  late List<ReminderLead> _reminders;
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
    _memo = TextEditingController(text: e?.memo ?? widget.draft?.memo ?? '');
    _date = e != null ? parseEventDate(e.date) : _dateOnly(widget.date);
    _endDate = e != null
        ? parseEventDate(e.effectiveEndDate)
        : _dateOnly(widget.date);
    _time = _parseTime(e?.time);
    _endTime = _parseTime(e?.endTime) ?? _defaultEndTime(_time);
    _notify = e?.notify ?? true;
    _reminders = sanitizeReminders(
      e?.reminders ?? const [ReminderLead.day1],
      allDay: _time == null,
    );
    _selectedCategoryId = e?.categoryId;
    _recurrence = e?.recurrence ?? RecurrenceType.none;
    _feastId = e?.feastId;
    final dr = widget.draft;
    if (e == null && dr != null) {
      _date = _dateOnly(parseEventDate(dr.date));
      _endDate = dr.endDate != null ? _dateOnly(parseEventDate(dr.endDate!)) : _date;
      _time = _parseTime(dr.time);
      _endTime = _parseTime(dr.endTime) ?? _defaultEndTime(_time);
      _reminders = sanitizeReminders(const [ReminderLead.day1], allDay: _time == null);
      // 카테고리는 비워둔다(_selectedCategoryId = null 유지). n/c는 사용하지 않음.
    }
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

  static TimeOfDay _plusOneHour(TimeOfDay time) =>
      TimeOfDay(hour: (time.hour + 1) % 24, minute: time.minute);

  static TimeOfDay? _defaultEndTime(TimeOfDay? start) =>
      start == null ? null : _plusOneHour(start);

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

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _date = _dateOnly(picked);
        if (_endDate.isBefore(_date)) _endDate = _date;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_date) ? _date : _endDate,
      firstDate: _date,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _endDate = _dateOnly(picked));
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _time = picked;
        _endTime ??= _plusOneHour(picked);
        _normalizeTimedEnd();
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? _defaultEndTime(_time) ?? _time!,
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
        _normalizeTimedEnd();
      });
    }
  }

  void _setAllDay(bool value) {
    setState(() {
      if (value) {
        _time = null;
        _endTime = null;
      } else {
        _time = const TimeOfDay(hour: 9, minute: 0);
        _endTime = const TimeOfDay(hour: 10, minute: 0);
      }
      _reminders = sanitizeReminders(_reminders, allDay: value);
    });
  }

  void _normalizeTimedEnd() {
    final start = _time;
    final end = _endTime;
    if (start == null || end == null || _endDate != _date) return;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    if (endMinutes <= startMinutes) {
      _endTime = _plusOneHour(start);
      final normalizedEnd = _endTime!;
      final normalizedMinutes = normalizedEnd.hour * 60 + normalizedEnd.minute;
      if (normalizedMinutes <= startMinutes) {
        _endDate = DateTime(_date.year, _date.month, _date.day + 1);
      }
    }
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
    final status = await service.notificationPermissionStatus();
    if (!mounted) return;
    if (status == NotificationPermissionStatus.notDetermined) {
      final granted = await service.requestNotificationPermission();
      if (!mounted) return;
      setState(() {
        _systemNotificationsEnabled = granted;
        _notify = granted;
      });
      return;
    }

    if (status == NotificationPermissionStatus.denied) {
      setState(() {
        _systemNotificationsEnabled = false;
        _notify = false;
      });
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: const Text('시스템 알림이 꺼져있어 알림을 보낼수 없습니다. 알림을 설정하시겠습니까?'),
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

  String _reminderHelpText() => '알림 시점을 선택하세요';

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
    final endTime = _endTime == null
        ? null
        : '${_two(_endTime!.hour)}:${_two(_endTime!.minute)}';
    final event = CalendarEvent(
      id:
          widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      date: eventDateKey(_date),
      endDate: eventDateKey(_endDate),
      categoryId: category.id,
      categoryName: category.name,
      categoryColor: category.color,
      memo: memo.isEmpty ? null : memo,
      time: time,
      endTime: endTime,
      notify: _systemNotificationsEnabled == false ? false : _notify,
      recurrence: _recurrence,
      feastId: _recurrence == RecurrenceType.yearlyFeast ? _feastId : null,
      reminders: _reminders,
    );

    final store = ref.read(eventStoreProvider.notifier);
    if (_isEditing) {
      await store.updateEvent(event);
    } else {
      await store.add(event);
      // 최초 1회: 일정 추가 완료 시점에 백업 안내(앱 실행/복원 시엔 뜨지 않음).
      if (mounted) await maybeShowBackupNotice(context, ref);
    }
    // 신규 저장일 때만 true를 돌려준다. showEventEditor가 이 값을 보고
    // 리뷰 요청 여부를 판단한다(수정/삭제/취소는 발동시키지 않는다).
    if (mounted) Navigator.of(context).pop(!_isEditing);
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('알림'),
        content: const Text('정말로 삭제하시겠습니까?', style: TextStyle(fontSize: 17)),
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
    if (confirmed != true) return;
    if (!mounted) return;
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
            // 카테고리 (필수) - 제목을 직접 입력하지 않고, 탭 → 카테고리 화면에서 선택.
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.label_outline),
              title: selected == null
                  ? const Text('카테고리를 선택하세요')
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: EventLabelHighlight.fromCategory(selected),
                    ),
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

            // 메모 (선택) - 자동 줄바꿈, 최대 100자, 완료(return) 키로 입력 종료.
            TextField(
              controller: _memo,
              minLines: 1,
              maxLines: null,
              maxLength: 100,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
              ],
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
              onChanged: _setAllDay,
            ),
            _DateTimeRow(
              label: '시작',
              date: _date,
              time: allDay ? null : _time!,
              onTapDate: _pickStartDate,
              onTapTime: allDay ? null : _pickStartTime,
            ),
            _DateTimeRow(
              label: '종료',
              date: _endDate,
              time: allDay ? null : _endTime!,
              onTapDate: _pickEndDate,
              onTapTime: allDay ? null : _pickEndTime,
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

            // 알림
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('알림'),
              subtitle: Text(_reminderHelpText()),
              value: _systemNotificationsEnabled == false ? false : _notify,
              onChanged: _toggleNotifications,
            ),
            if (_systemNotificationsEnabled != false && _notify)
              ReminderEditor(
                reminders: _reminders,
                allDay: _time == null,
                onChanged: (v) => setState(() => _reminders = v),
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

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.label,
    required this.date,
    required this.time,
    required this.onTapDate,
    required this.onTapTime,
  });

  final String label;
  final DateTime date;
  final TimeOfDay? time;
  final VoidCallback onTapDate;
  final VoidCallback? onTapTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = this.time;
    return Padding(
      padding: const EdgeInsets.only(left: 40),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(label, style: theme.textTheme.titleMedium),
          ),
          const Spacer(),
          TextButton(onPressed: onTapDate, child: Text(_dateButtonLabel(date))),
          if (time != null) ...[
            const SizedBox(width: 4),
            TextButton(onPressed: onTapTime, child: Text(time.format(context))),
          ],
        ],
      ),
    );
  }
}
