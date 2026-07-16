import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

import '../../../../app/theme/liturgical_colors.dart';
import '../../../events/application/event_providers.dart';
import '../../../events/model/calendar_event.dart';

const _weekdayFull = ['일', '월', '화', '수', '목', '금', '토'];
const _maxMemorialRows = 3;
const _maxEventRows = 2;

/// 달력 하단 고정 정보영역: 얇은 구분선 + 날짜 + 기념/전례명 + 그날의 내 일정 요약.
class DayInfoBar extends ConsumerWidget {
  const DayInfoBar({super.key, required this.day, required this.onTapDetail});

  final LiturgicalDay day;
  final VoidCallback onTapDetail; // 축일/일정 영역 탭 → 상세

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final d = day.date;
    final weekday = _weekdayFull[d.weekday % 7];
    final events = ref.watch(eventsForDateProvider(d));
    final memorials = [
      _MemorialLine(title: day.title, color: day.color),
      for (final m in day.optionalMemorials)
        _MemorialLine(title: m.name, color: m.color),
    ].take(_maxMemorialRows).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: theme.dividerColor.withValues(alpha: 0.4),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${d.month}월 ${d.day}일 $weekday요일',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF121212),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: onTapDetail,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < _maxMemorialRows; i++)
                        _MemorialRow(
                          line: i < memorials.length ? memorials[i] : null,
                        ),
                      if (events.isNotEmpty) _EventSummary(events: events),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The day's personal events, summarized under the liturgical names.
class _EventSummary extends StatelessWidget {
  const _EventSummary({required this.events});

  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = events.take(_maxEventRows).toList();
    final extra = events.length - shown.length;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(
            height: 12,
            color: theme.dividerColor.withValues(alpha: 0.3),
          ),
          for (final e in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.event_note_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    e.isAllDay ? '종일' : e.time!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          if (extra > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 24),
              child: Text(
                '+$extra개 더',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MemorialLine {
  const _MemorialLine({required this.title, required this.color});

  final String title;
  final LiturgicalColor color;
}

class _MemorialRow extends StatelessWidget {
  const _MemorialRow({required this.line});

  final _MemorialLine? line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 26,
      child: line == null
          ? const SizedBox.shrink()
          : Row(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.liturgical.of(line!.color),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
    );
  }
}
