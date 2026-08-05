import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

import '../../../../app/theme/liturgical_colors.dart';
import '../../../events/application/event_providers.dart';
import '../../../events/model/calendar_event.dart';
import '../../../events/presentation/event_display.dart';

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
      _MemorialLine(
        id: day.celebration.id,
        title: day.title,
        color: day.color,
        rank: day.celebration.rank,
        displayType: day.celebration.displayType,
      ),
      for (final m in day.optionalMemorials)
        _MemorialLine(
          id: m.id,
          title: m.name,
          color: m.color,
          rank: m.rank,
          displayType: m.displayType,
        ),
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
    final feastSummary = first.isSaintFeast
        ? [
            first.saintName?.trim().isNotEmpty == true
                ? first.saintName!.trim()
                : first.title,
            if (memo != null && memo.isNotEmpty) memo,
          ].join(' ')
        : null;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (first.isSaintFeast) ...[
                EventLabelHighlight(
                  label: kSaintFeastPrefix,
                  color: const Color(kSaintFeastEventColor),
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: first.isSaintFeast
                    ? Text(
                        feastSummary!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge,
                      )
                    : RegularEventDisplayLine(
                        event: first,
                        showAllDayLabel: false,
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
  const _MemorialLine({
    required this.id,
    required this.title,
    required this.color,
    required this.rank,
    this.displayType,
  });

  final String id;
  final String title;
  final LiturgicalColor color;
  final Rank rank;
  final LiturgicalDisplayType? displayType;
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
          EventLabelHighlight(
            label: _memorialTypeLabel(
              line.id,
              line.title,
              line.rank,
              line.displayType,
            ),
            color: context.liturgical.of(line.color),
            style: theme.textTheme.bodyLarge,
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

String _memorialTypeLabel(
  String id,
  String title,
  Rank rank,
  LiturgicalDisplayType? displayType,
) {
  switch (displayType) {
    case LiturgicalDisplayType.saintFeast:
      return '축일';
    case LiturgicalDisplayType.liturgy:
    case LiturgicalDisplayType.review:
      return '전례';
    case null:
      break;
  }
  if (_isLiturgicalOnlyMemorial(id, title, rank)) {
    return '전례';
  }
  if (_isSaintFeastMemorial(title)) {
    return '축일';
  }
  return '전례';
}

bool _isLiturgicalOnlyMemorial(String id, String title, Rank rank) {
  return id == 'all_souls' ||
      title.contains('위령의 날') ||
      rank == Rank.solemnity ||
      rank == Rank.feastOfTheLord;
}

bool _isSaintFeastMemorial(String title) {
  return _looksLikeSaintTitle(title) ||
      title.contains('복되신 동정 마리아') ||
      title.contains('성모') ||
      title.contains('대천사') ||
      title.contains('수호천사') ||
      title.contains('죄 없는 아기 순교자');
}

bool _looksLikeSaintTitle(String title) {
  return title.startsWith('성 ') ||
      title.startsWith('성녀 ') ||
      title.startsWith('성인 ') ||
      title.startsWith('복자 ') ||
      title.startsWith('복녀 ') ||
      title.contains(' 성 ') ||
      title.contains(' 성녀 ') ||
      title.contains(' 복자 ') ||
      title.contains(' 복녀 ');
}
