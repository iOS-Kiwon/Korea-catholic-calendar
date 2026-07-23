import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

import '../../../../app/theme/liturgical_colors.dart';
import '../../../events/application/event_providers.dart';
import '../../../events/model/calendar_event.dart';

const _weekdayFull = ['일', '월', '화', '수', '목', '금', '토'];
const _maxMemorialRows = 3;

/// 달력 하단 정보 카드: 날짜(+상세 이동 셰브런) · 기념/전례명 · 그날의 내 일정 요약,
/// 그리고 (해당하는 날) 나눔 배너. 카드 영역을 누르면 상세 화면으로 이동한다.
class DayInfoBar extends ConsumerWidget {
  const DayInfoBar({
    super.key,
    required this.day,
    required this.onTapDetail,
    this.onSupportTap,
  });

  final LiturgicalDay day;
  final VoidCallback onTapDetail; // 카드 상단(날짜/기념/일정) 탭 → 상세
  final VoidCallback? onSupportTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final d = day.date;
    final weekday = _weekdayFull[d.weekday % 7];
    final events = ref.watch(eventsForDateProvider(d));
    final showSupportInvite =
        onSupportTap != null &&
        (day.celebration.rank == Rank.solemnity ||
            day.celebration.rank == Rank.feastOfTheLord);
    final memorials = [
      _MemorialLine(title: day.title, color: day.color),
      for (final m in day.optionalMemorials)
        _MemorialLine(title: m.name, color: m.color),
    ].take(_maxMemorialRows).toList();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜 + 기념/전례명 + 일정 요약 (탭하면 상세)
            InkWell(
              onTap: onTapDetail,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${d.month}월 ${d.day}일 $weekday요일',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF121212),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final line in memorials) _MemorialRow(line: line),
                  if (events.isNotEmpty) _EventSummary(events: events),
                ],
              ),
            ),
            if (showSupportInvite) ...[
              const SizedBox(height: 14),
              _SupportBanner(onTap: onSupportTap!),
            ],
          ],
        ),
      ),
    );
  }
}

/// The day's personal events, summarized under the liturgical names.
/// Shows the first event as time/category/memo in one line, then a count when
/// there are more.
class _EventSummary extends StatelessWidget {
  const _EventSummary({required this.events});

  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = events.first;
    final extra = events.length - 1;
    final memo = first.memo?.trim();
    final summary = first.isSaintFeast
        ? [
            first.saintName?.trim().isNotEmpty == true
                ? first.saintName!.trim()
                : first.title,
            if (memo != null && memo.isNotEmpty) memo,
          ].join(' ')
        : [
            first.isAllDay ? '종일' : first.time!,
            first.title,
            if (memo != null && memo.isNotEmpty) memo,
          ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 20, color: theme.dividerColor.withValues(alpha: 0.4)),
          Row(
            children: [
              if (first.isSaintFeast)
                const Text(kSaintFeastPrefix, style: TextStyle(fontSize: 13))
              else
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(first.categoryColor),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
          if (extra > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 18),
              child: Text(
                '외 $extra개 일정이 있어요.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 나눔(응원) 배너. 연한 녹색 배경 + 하트 + 셰브런.
class _SupportBanner extends StatelessWidget {
  const _SupportBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Material(
      color: accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.favorite, color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '오늘의 기쁨을 나눠요',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: accent),
            ],
          ),
        ),
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

  final _MemorialLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.liturgical.of(line.color),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              line.title,
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
