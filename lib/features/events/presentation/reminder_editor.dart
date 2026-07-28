import 'package:flutter/material.dart';

import '../model/reminder_lead.dart';

/// 알림 리드타임 목록 편집기(최대 [max]개). 종일이면 분/시간 리드는 숨긴다.
/// 상태는 상위가 소유([reminders]) - 변경 시 [onChanged]로 새 목록 전달.
class ReminderEditor extends StatelessWidget {
  const ReminderEditor({
    super.key,
    required this.reminders,
    required this.allDay,
    required this.onChanged,
    this.max = 2,
  });

  final List<ReminderLead> reminders;
  final bool allDay;
  final ValueChanged<List<ReminderLead>> onChanged;
  final int max;

  List<ReminderLead> get _available => allDay
      ? ReminderLead.values.where((l) => !l.isSubDay).toList()
      : ReminderLead.values.toList();

  Future<void> _pick(BuildContext context, int index) async {
    final picked = await showModalBottomSheet<ReminderLead>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final l in _available)
              ListTile(
                title: Text(l.displayName),
                trailing: reminders[index] == l ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(ctx).pop(l),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      final next = [...reminders];
      next[index] = picked;
      onChanged(next);
    }
  }

  void _add() {
    final used = reminders.toSet();
    final candidate = _available.firstWhere(
      (l) => !used.contains(l),
      orElse: () => _available.first,
    );
    onChanged([...reminders, candidate]);
  }

  void _remove(int index) {
    final next = [...reminders]..removeAt(index);
    onChanged(next.isEmpty ? const [ReminderLead.day1] : next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < reminders.length; i++)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 40, right: 8),
            title: Text('알림 ${i + 1}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reminders[i].displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (reminders.length > 1)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: '삭제',
                    onPressed: () => _remove(i),
                  )
                else
                  const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _pick(context, i),
          ),
        if (reminders.length < max)
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('알림 추가'),
              ),
            ),
          ),
      ],
    );
  }
}

/// 종일 여부에 맞게 리드 목록을 보정(종일이면 분/시간 제거). 비면 [day1].
List<ReminderLead> sanitizeReminders(List<ReminderLead> reminders, {required bool allDay}) {
  final filtered = allDay ? reminders.where((l) => !l.isSubDay).toList() : reminders.toList();
  return filtered.isEmpty ? const [ReminderLead.day1] : filtered;
}
