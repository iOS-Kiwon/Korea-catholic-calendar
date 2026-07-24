import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ads/ads.dart';
import '../../events/application/event_providers.dart';
import '../../events/model/calendar_event.dart';
import '../../events/model/recurrence.dart';
import '../../events/presentation/backup_notice.dart';
import '../model/saint.dart';
import 'saint_search_page.dart';

const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];
const _saintCategoryId = 'saint_feast';
const _saintCategoryName = '축일';

String _dateLabel(DateTime d) =>
    '${d.year}년 ${d.month}월 ${d.day}일 (${_weekdays[d.weekday % 7]})';

Future<void> showSaintFeastEditor(
  BuildContext context, {
  required DateTime date,
  CalendarEvent? existing,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => SaintFeastEditorPage(date: date, existing: existing),
    ),
  );
}

class SaintFeastEditorPage extends ConsumerStatefulWidget {
  const SaintFeastEditorPage({super.key, required this.date, this.existing});

  final DateTime date;
  final CalendarEvent? existing;

  @override
  ConsumerState<SaintFeastEditorPage> createState() =>
      _SaintFeastEditorPageState();
}

class _SaintFeastEditorPageState extends ConsumerState<SaintFeastEditorPage>
    with WidgetsBindingObserver {
  late final TextEditingController _memo;
  late DateTime _date;
  late bool _notify;
  Saint? _saint;
  bool _saintError = false;
  bool? _systemNotificationsEnabled;
  bool _enableNotifyWhenPermissionReturns = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final e = widget.existing;
    _memo = TextEditingController(text: e?.memo ?? '');
    _date = e != null ? parseEventDate(e.date) : _dateOnly(widget.date);
    _notify = e?.notify ?? true;
    if (e?.saintId != null) {
      _saint = Saint(
        id: e!.saintId!,
        nameKo: e.saintName ?? e.title,
        nameLatin: '',
        url: e.saintUrl ?? '',
        feastMonth: _date.month,
        feastDay: _date.day,
      );
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

  Future<void> _pickSaint() async {
    final saint = await Navigator.of(context).push<Saint>(
      MaterialPageRoute<Saint>(builder: (_) => const SaintSearchPage()),
    );
    if (saint == null) return;
    setState(() {
      _saint = saint;
      _saintError = false;
      if (saint.feastMonth != null && saint.feastDay != null) {
        _date = DateTime(_date.year, saint.feastMonth!, saint.feastDay!);
      }
    });
  }

  Future<void> _openSaintUrl() async {
    final raw = _saint?.url.trim();
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    final openedInApp = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!openedInApp) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  String _reminderHelpText() {
    return '알림은 전날 오후 9:00, 당일 오전 9:00에 보냅니다. 이미 지난 시간의 알림은 예약하지 않습니다.';
  }

  Future<void> _save() async {
    final saint = _saint;
    if (saint == null) {
      setState(() => _saintError = true);
      return;
    }
    final memo = _memo.text.trim();
    final event = CalendarEvent(
      id:
          widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      date: eventDateKey(_date),
      categoryId: _saintCategoryId,
      categoryName: _saintCategoryName,
      categoryColor: kSaintFeastEventColor,
      memo: memo.isEmpty ? null : memo,
      time: null,
      notify: _systemNotificationsEnabled == false ? false : _notify,
      type: CalendarEventType.saintFeast,
      saintId: saint.id,
      saintName: saint.nameKo,
      saintUrl: saint.url,
      // 축일은 기본적으로 매년 같은 월·일에 반복(전례력과 무관하게 날짜 기준).
      recurrence: RecurrenceType.yearlyDate,
    );

    final store = ref.read(eventStoreProvider.notifier);
    if (_isEditing) {
      await store.updateEvent(event);
    } else {
      await store.add(event);
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
    final saint = _saint;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '축일 수정' : '새 축일'),
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_search_outlined),
              title: Text(saint?.nameKo ?? '성인을 선택하세요'),
              subtitle: _saintError
                  ? Text(
                      '성인을 선택하세요',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    )
                  : saint == null
                  ? null
                  : Text(saint.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickSaint,
            ),
            if (saint != null && saint.url.trim().isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _openSaintUrl,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('성인 정보 보기'),
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(_dateLabel(_date)),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: _pickDate,
            ),
            const SizedBox(height: 4),
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
      bottomNavigationBar: SafeArea(
        top: false,
        bottom: !adsEnabled,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
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
